#!/usr/bin/env python3
import argparse
import hashlib
import http.client
import ipaddress
import json
import os
import re
import selectors
import socket
import ssl
import stat
import struct
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
import uuid
import zlib
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

SOCKET_NAME = "windows_manager_linux_orgm.sock"
MAX_MESSAGE_BYTES = 64 * 1024

FAVICON_CACHE_DIRECTORY = "windows-manager-linux-orgm/favicons"
FAVICON_TIMEOUT_SECONDS = 2
MAX_FAVICON_BYTES = 512 * 1024
MAX_FAVICON_CACHE_ENTRIES = 128
MAX_FAVICON_CACHE_BYTES = 32 * 1024 * 1024
FAVICON_CACHE_TTL_SECONDS = 30 * 24 * 60 * 60
MAX_FAVICON_WORK_ITEMS = 4
MAX_FAVICON_PIXELS = 4 * 1024 * 1024
MAX_FAVICON_DIMENSION = 4096
MAX_FAVICON_FRAMES = 32
FAVICON_READ_CHUNK_BYTES = 16 * 1024
FAVICON_TYPES = {
    "image/png": "png",
    "image/jpeg": "jpg",
    "image/gif": "gif",
    "image/webp": "webp",
    "image/x-icon": "ico",
    "image/vnd.microsoft.icon": "ico",
}
FAVICON_SUFFIXES = tuple(sorted(set(FAVICON_TYPES.values())))


def runtime_dir():
    return Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))


def socket_path():
    return runtime_dir() / SOCKET_NAME


def valid_url(url):
    parsed = urlsplit(url)
    return parsed.scheme in {"http", "https"} and bool(parsed.netloc)


def _is_global_address(address):
    try:
        return ipaddress.ip_address(address).is_global
    except ValueError:
        return False


def canonical_favicon_url(url):
    if not isinstance(url, str) or not url or any(ord(char) < 0x20 for char in url):
        return None
    try:
        parsed = urlsplit(url)
        if (
            parsed.scheme.lower() != "https"
            or not parsed.hostname
            or parsed.username is not None
            or parsed.password is not None
        ):
            return None
        host = parsed.hostname.encode("idna").decode("ascii").lower()
        port = parsed.port
    except (UnicodeError, ValueError):
        return None
    try:
        literal = ipaddress.ip_address(host)
    except ValueError:
        literal = None
    if literal is not None and not literal.is_global:
        return None
    if ":" in host:
        host = f"[{host}]"
    if port is not None and port != 443:
        host = f"{host}:{port}"
    return urlunsplit(("https", host, parsed.path or "/", parsed.query, ""))


def favicon_cache_dir():
    cache_home = os.environ.get("XDG_CACHE_HOME")
    if cache_home:
        return Path(cache_home) / FAVICON_CACHE_DIRECTORY
    return Path.home() / ".cache" / FAVICON_CACHE_DIRECTORY


class RejectRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, new_url):
        raise urllib.error.HTTPError(
            request.full_url, code, "favicon redirects are not allowed", headers, fp
        )


def _valid_dimensions(width, height, frames=1):
    return (
        0 < width <= MAX_FAVICON_DIMENSION
        and 0 < height <= MAX_FAVICON_DIMENSION
        and 0 < frames <= MAX_FAVICON_FRAMES
        and width * height <= MAX_FAVICON_PIXELS
        and width * height * frames <= MAX_FAVICON_PIXELS
    )


def _png_image_info(data):
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        return None
    offset = 8
    width = height = None
    idat = bytearray()
    saw_iend = False
    while offset < len(data):
        if len(data) - offset < 12:
            return None
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        chunk_end = offset + 12 + length
        if chunk_end > len(data):
            return None
        chunk_type = data[offset + 4 : offset + 8]
        chunk = data[offset + 8 : offset + 8 + length]
        checksum = struct.unpack(">I", data[offset + 8 + length : chunk_end])[0]
        if zlib.crc32(chunk_type + chunk) & 0xFFFFFFFF != checksum:
            return None
        if width is None:
            if chunk_type != b"IHDR" or length != 13:
                return None
            width, height, depth, color_type, compression, filtering, interlace = struct.unpack(
                ">IIBBBBB", chunk
            )
            components = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color_type)
            valid_depths = {
                0: {1, 2, 4, 8, 16},
                2: {8, 16},
                3: {1, 2, 4, 8},
                4: {8, 16},
                6: {8, 16},
            }
            if (
                components is None
                or depth not in valid_depths[color_type]
                or compression != 0
                or filtering != 0
                or interlace != 0
                or not _valid_dimensions(width, height)
            ):
                return None
            row_bytes = (width * components * depth + 7) // 8
            expected_decoded_bytes = (row_bytes + 1) * height
            if expected_decoded_bytes > MAX_FAVICON_PIXELS * 8:
                return None
        elif chunk_type == b"IDAT":
            if saw_iend:
                return None
            idat.extend(chunk)
        elif chunk_type == b"IEND":
            if length != 0 or not idat or saw_iend or chunk_end != len(data):
                return None
            saw_iend = True
        elif chunk_type in {b"acTL", b"fcTL", b"fdAT"}:
            return None
        if saw_iend:
            break
        offset = chunk_end
    if width is None or not saw_iend:
        return None
    try:
        decoder = zlib.decompressobj()
        decoded = decoder.decompress(bytes(idat), expected_decoded_bytes + 1)
        decoded += decoder.flush(expected_decoded_bytes + 1 - len(decoded))
    except zlib.error:
        return None
    if not decoder.eof or decoder.unused_data or len(decoded) != expected_decoded_bytes:
        return None
    return width, height, 1


def _jpeg_image_info(data):
    if len(data) < 4 or not data.startswith(b"\xff\xd8"):
        return None
    offset = 2
    width = height = None
    saw_eoi = False
    sof_markers = {
        0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
        0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF,
    }
    while offset < len(data):
        if data[offset] != 0xFF:
            offset += 1
            continue
        while offset < len(data) and data[offset] == 0xFF:
            offset += 1
        if offset >= len(data):
            return None
        marker = data[offset]
        offset += 1
        if marker == 0x00 or 0xD0 <= marker <= 0xD7 or marker == 0x01:
            continue
        if marker == 0xD9:
            saw_eoi = offset == len(data)
            break
        if offset + 2 > len(data):
            return None
        length = struct.unpack(">H", data[offset : offset + 2])[0]
        if length < 2 or offset + length > len(data):
            return None
        if marker in sof_markers:
            if length < 8:
                return None
            height, width = struct.unpack(">HH", data[offset + 3 : offset + 7])
            components = data[offset + 7]
            if components == 0 or length != 8 + 3 * components or not _valid_dimensions(width, height):
                return None
        offset += length
    if not saw_eoi or width is None or height is None:
        return None
    return width, height, 1


def _gif_subblocks(data, offset):
    blocks = bytearray()
    while True:
        if offset >= len(data):
            return None, offset
        length = data[offset]
        offset += 1
        if length == 0:
            return bytes(blocks), offset
        if offset + length > len(data):
            return None, offset
        blocks.extend(data[offset : offset + length])
        offset += length


def _gif_lzw_pixels(encoded, minimum_code_size, expected_pixels):
    if not 2 <= minimum_code_size <= 8:
        return False
    clear = 1 << minimum_code_size
    end = clear + 1
    dictionary = {code: bytes([code]) for code in range(clear)}
    code_size = minimum_code_size + 1
    next_code = end + 1
    bit_offset = 0
    previous = None
    pixels = 0
    saw_clear = False
    while bit_offset + code_size <= len(encoded) * 8:
        code = (int.from_bytes(encoded[bit_offset // 8 : bit_offset // 8 + 4], "little") >> (bit_offset % 8)) & ((1 << code_size) - 1)
        bit_offset += code_size
        if code == clear:
            dictionary = {value: bytes([value]) for value in range(clear)}
            code_size = minimum_code_size + 1
            next_code = end + 1
            previous = None
            saw_clear = True
            continue
        if code == end:
            return saw_clear and pixels == expected_pixels
        if not saw_clear:
            return False
        if code in dictionary:
            entry = dictionary[code]
        elif code == next_code and previous is not None:
            entry = previous + previous[:1]
        else:
            return False
        pixels += len(entry)
        if pixels > expected_pixels:
            return False
        if previous is not None and next_code < 4096:
            dictionary[next_code] = previous + entry[:1]
            next_code += 1
            if next_code == (1 << code_size) and code_size < 12:
                code_size += 1
        previous = entry
    return False


def _gif_image_info(data):
    if len(data) < 14 or data[:6] not in (b"GIF87a", b"GIF89a"):
        return None
    width, height = struct.unpack("<HH", data[6:10])
    if not _valid_dimensions(width, height):
        return None
    offset = 13
    packed = data[10]
    if packed & 0x80:
        table_size = 3 * (1 << ((packed & 0x07) + 1))
        if offset + table_size > len(data):
            return None
        offset += table_size
    frames = total_pixels = 0
    while offset < len(data):
        marker = data[offset]
        offset += 1
        if marker == 0x3B:
            return (width, height, frames) if offset == len(data) and frames else None
        if marker == 0x21:
            if offset >= len(data):
                return None
            label = data[offset]
            offset += 1
            if label == 0xF9:
                if offset + 6 > len(data) or data[offset] != 4 or data[offset + 5] != 0:
                    return None
                offset += 6
            else:
                _, offset = _gif_subblocks(data, offset)
                if _ is None:
                    return None
            continue
        if marker != 0x2C or offset + 9 > len(data):
            return None
        _, _, image_width, image_height = struct.unpack("<HHHH", data[offset : offset + 8])
        packed = data[offset + 8]
        offset += 9
        if not _valid_dimensions(image_width, image_height):
            return None
        if packed & 0x80:
            table_size = 3 * (1 << ((packed & 0x07) + 1))
            if offset + table_size > len(data):
                return None
            offset += table_size
        if offset >= len(data):
            return None
        minimum_code_size = data[offset]
        encoded, offset = _gif_subblocks(data, offset + 1)
        if encoded is None or not 2 <= minimum_code_size <= 8:
            return None
        frames += 1
        total_pixels += image_width * image_height
        if frames > MAX_FAVICON_FRAMES or total_pixels > MAX_FAVICON_PIXELS:
            return None
    return None


def _webp_image_info(data):
    if len(data) < 20 or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        return None
    if struct.unpack("<I", data[4:8])[0] + 8 != len(data):
        return None
    offset = 12
    width = height = None
    frames = 0
    animated = False
    saw_image = False
    while offset < len(data):
        if offset + 8 > len(data):
            return None
        chunk_type = data[offset : offset + 4]
        length = struct.unpack("<I", data[offset + 4 : offset + 8])[0]
        content_start = offset + 8
        content_end = content_start + length
        offset = content_end + (length & 1)
        if offset > len(data):
            return None
        chunk = data[content_start:content_end]
        if chunk_type == b"VP8X":
            if length != 10 or width is not None:
                return None
            animated = bool(chunk[0] & 0x02)
            width = int.from_bytes(chunk[4:7], "little") + 1
            height = int.from_bytes(chunk[7:10], "little") + 1
            if not _valid_dimensions(width, height):
                return None
        elif chunk_type == b"VP8 ":
            if length < 10 or chunk[3:6] != b"\x9d\x01\x2a":
                return None
            image_width = struct.unpack("<H", chunk[6:8])[0] & 0x3FFF
            image_height = struct.unpack("<H", chunk[8:10])[0] & 0x3FFF
            if not _valid_dimensions(image_width, image_height):
                return None
            if width is None:
                width, height = image_width, image_height
            elif (width, height) != (image_width, image_height):
                return None
            saw_image = True
        elif chunk_type == b"VP8L":
            if length < 5 or chunk[0] != 0x2F:
                return None
            bits = int.from_bytes(chunk[1:5], "little")
            image_width = (bits & 0x3FFF) + 1
            image_height = ((bits >> 14) & 0x3FFF) + 1
            if not _valid_dimensions(image_width, image_height):
                return None
            if width is None:
                width, height = image_width, image_height
            elif (width, height) != (image_width, image_height):
                return None
            saw_image = True
        elif chunk_type == b"ANIM":
            if length != 6:
                return None
            animated = True
        elif chunk_type == b"ANMF":
            if length < 16:
                return None
            frame_width = int.from_bytes(chunk[6:9], "little") + 1
            frame_height = int.from_bytes(chunk[9:12], "little") + 1
            if not _valid_dimensions(frame_width, frame_height):
                return None
            frames += 1
            if frames > MAX_FAVICON_FRAMES:
                return None
            saw_image = True
    if offset != len(data) or width is None or not saw_image:
        return None
    if animated and not _valid_dimensions(width, height, max(frames, 1)):
        return None
    return width, height, max(frames, 1)


def _ico_image_info(data):
    if len(data) < 22 or data[:4] not in (b"\x00\x00\x01\x00", b"\x00\x00\x02\x00"):
        return None
    count = struct.unpack("<H", data[4:6])[0]
    if not 0 < count <= MAX_FAVICON_FRAMES or len(data) < 6 + 16 * count:
        return None
    total_pixels = 0
    for index in range(count):
        entry = data[6 + index * 16 : 22 + index * 16]
        width = entry[0] or 256
        height = entry[1] or 256
        size, offset = struct.unpack("<II", entry[8:16])
        if not _valid_dimensions(width, height) or not size or offset + size > len(data):
            return None
        image = data[offset : offset + size]
        if image.startswith(b"\x89PNG\r\n\x1a\n"):
            info = _png_image_info(image)
            if info is None:
                return None
            image_width, image_height, _ = info
        else:
            if len(image) < 40:
                return None
            header_size = struct.unpack("<I", image[:4])[0]
            if header_size < 40 or header_size > len(image):
                return None
            image_width, raw_height = struct.unpack("<ii", image[4:12])
            planes, bits_per_pixel = struct.unpack("<HH", image[12:16])
            compression = struct.unpack("<I", image[16:20])[0]
            if image_width <= 0 or raw_height == 0 or raw_height % 2 or planes != 1 or bits_per_pixel not in {1, 4, 8, 16, 24, 32} or compression != 0:
                return None
            image_width = abs(image_width)
            image_height = abs(raw_height) // 2
            if image_width != width or image_height != height or not _valid_dimensions(image_width, image_height):
                return None
            palette_entries = struct.unpack("<I", image[32:36])[0] or (1 << bits_per_pixel if bits_per_pixel <= 8 else 0)
            row_bytes = ((image_width * bits_per_pixel + 31) // 32) * 4
            mask_row_bytes = ((image_width + 31) // 32) * 4
            if header_size + palette_entries * 4 + (row_bytes + mask_row_bytes) * image_height > len(image):
                return None
        total_pixels += image_width * image_height
        if total_pixels > MAX_FAVICON_PIXELS:
            return None
    return 1, 1, count


def favicon_image_info(data, suffix):
    if not isinstance(data, bytes) or not data or len(data) > MAX_FAVICON_BYTES:
        return None
    parsers = {
        "png": _png_image_info,
        "jpg": _jpeg_image_info,
        "gif": _gif_image_info,
        "webp": _webp_image_info,
        "ico": _ico_image_info,
    }
    parser = parsers.get(suffix)
    return parser(data) if parser is not None else None


def valid_favicon_image(data, suffix):
    return favicon_image_info(data, suffix) is not None


class ApprovedHTTPSConnection(http.client.HTTPSConnection):
    """HTTPS connection pinned to a pre-approved address, with host TLS validation."""

    def __init__(self, host, port, address, timeout):
        super().__init__(host, port=port, timeout=timeout, context=ssl.create_default_context())
        self.approved_address = address

    def connect(self):
        self.sock = socket.create_connection((self.approved_address, self.port), self.timeout)
        self.sock = self._context.wrap_socket(self.sock, server_hostname=self.host)


class FaviconCache:
    def __init__(self, cache_dir=None, fetcher=None, opener_factory=None, resolver=None, connection_factory=None):
        self.cache_dir = Path(cache_dir or favicon_cache_dir()).expanduser().resolve()
        self.fetcher = fetcher
        # Retained as a testable redirect policy object for callers that use urllib.
        self.opener_factory = opener_factory or (lambda: urllib.request.build_opener(RejectRedirects()))
        self.resolver = resolver or (
            lambda host, port: socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)
        )
        self.connection_factory = connection_factory or ApprovedHTTPSConnection
        self.executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="favicon-cache")
        self.in_flight = set()
        self.lock = threading.Lock()

    def close(self):
        self.executor.shutdown(wait=False, cancel_futures=True)

    def _prepare_directory(self):
        if self.cache_dir.is_symlink():
            raise OSError("favicon cache directory must not be a symlink")
        self.cache_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
        if not stat.S_ISDIR(self.cache_dir.lstat().st_mode):
            raise OSError("favicon cache path is not a directory")
        self.cache_dir.chmod(0o700)

    @staticmethod
    def _cache_key(url):
        return hashlib.sha256(url.encode("utf-8")).hexdigest()

    def _cache_path(self, url, suffix):
        return self.cache_dir / f"{self._cache_key(url)}.{suffix}"

    def _valid_cached_file(self, path, suffix):
        try:
            info = path.lstat()
            if (
                not stat.S_ISREG(info.st_mode)
                or stat.S_ISLNK(info.st_mode)
                or info.st_size <= 0
                or info.st_size > MAX_FAVICON_BYTES
                or time.time() - info.st_mtime > FAVICON_CACHE_TTL_SECONDS
            ):
                path.unlink(missing_ok=True)
                return None
            with path.open("rb") as cached:
                data = cached.read(MAX_FAVICON_BYTES + 1)
            if not valid_favicon_image(data, suffix):
                path.unlink(missing_ok=True)
                return None
            path.chmod(0o600)
            os.utime(path, (time.time(), info.st_mtime))
            return path
        except OSError:
            return None

    def _get_canonical(self, canonical_url):
        try:
            self._prepare_directory()
            for suffix in FAVICON_SUFFIXES:
                cached = self._valid_cached_file(self._cache_path(canonical_url, suffix), suffix)
                if cached is not None:
                    return cached
        except OSError:
            return None
        return None

    def get(self, url):
        canonical_url = canonical_favicon_url(url)
        return self._get_canonical(canonical_url) if canonical_url is not None else None

    @staticmethod
    def _resolved_global_address(host, port, resolver):
        try:
            literal = ipaddress.ip_address(host)
        except ValueError:
            literal = None
        if literal is not None:
            if not literal.is_global:
                raise ValueError("favicon host is not globally routable")
            return str(literal)
        records = resolver(host, port)
        addresses = []
        for record in records:
            try:
                address = record[4][0]
                parsed = ipaddress.ip_address(address)
            except (IndexError, TypeError, ValueError):
                raise ValueError("favicon host resolution returned an invalid address") from None
            if not parsed.is_global:
                raise ValueError("favicon host resolves to a non-global address")
            addresses.append(str(parsed))
        if not addresses:
            raise ValueError("favicon host did not resolve")
        return addresses[0]

    @staticmethod
    def _read_response(response, connection, deadline):
        data = bytearray()
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("favicon fetch exceeded total deadline")
            if connection.sock is not None:
                connection.sock.settimeout(min(FAVICON_TIMEOUT_SECONDS, remaining))
            read = getattr(response, "read1", None) or response.read
            chunk = read(min(FAVICON_READ_CHUNK_BYTES, MAX_FAVICON_BYTES + 1 - len(data)))
            if not chunk:
                return bytes(data)
            data.extend(chunk)
            if len(data) > MAX_FAVICON_BYTES:
                raise ValueError("favicon response exceeds maximum size")

    def _fetch(self, url):
        if self.fetcher is not None:
            content_type, data = self.fetcher(url)
            return content_type, data
        parsed = urlsplit(url)
        host = parsed.hostname
        if host is None:
            raise ValueError("favicon URL has no host")
        port = parsed.port or 443
        address = self._resolved_global_address(host, port, self.resolver)
        connection = self.connection_factory(host, port, address, FAVICON_TIMEOUT_SECONDS)
        deadline = time.monotonic() + FAVICON_TIMEOUT_SECONDS
        try:
            target = parsed.path or "/"
            if parsed.query:
                target += f"?{parsed.query}"
            connection.request(
                "GET",
                target,
                headers={
                    "Accept": ", ".join(FAVICON_TYPES),
                    "Host": host if port == 443 else f"{host}:{port}",
                    "User-Agent": "windows-manager-linux-orgm favicon cache",
                },
            )
            response = connection.getresponse()
            if not 200 <= response.status < 300:
                raise ValueError("favicon response was not successful")
            content_length = response.headers.get("Content-Length")
            if content_length is not None:
                try:
                    length = int(content_length)
                except ValueError as error:
                    raise ValueError("invalid favicon content length") from error
                if length < 0 or length > MAX_FAVICON_BYTES:
                    raise ValueError("favicon response exceeds maximum size")
            return response.headers.get("Content-Type", ""), self._read_response(response, connection, deadline)
        finally:
            connection.close()

    def _store(self, url, content_type, data):
        content_type = content_type.split(";", 1)[0].strip().lower()
        suffix = FAVICON_TYPES.get(content_type)
        if suffix is None or not valid_favicon_image(data, suffix):
            raise ValueError("favicon response is not an accepted image")
        self._prepare_directory()
        destination = self._cache_path(url, suffix)
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="wb", dir=self.cache_dir, prefix=f".{self._cache_key(url)}.", delete=False
            ) as output:
                temporary = Path(output.name)
                os.fchmod(output.fileno(), 0o600)
                output.write(data)
                output.flush()
                os.fsync(output.fileno())
            os.replace(temporary, destination)
            destination.chmod(0o600)
            self._evict()
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)

    def _evict(self):
        now = time.time()
        entries = []
        temporary_pattern = re.compile(r"\.[0-9a-f]{64}\..+")
        for path in self.cache_dir.iterdir():
            name = path.name
            is_entry = (
                "." in name
                and len(name.rsplit(".", 1)[0]) == 64
                and name.rsplit(".", 1)[1] in FAVICON_SUFFIXES
            )
            is_temporary = temporary_pattern.fullmatch(name) is not None
            if path.is_symlink() or not (is_entry or is_temporary):
                continue
            try:
                info = path.stat()
            except OSError:
                continue
            if not stat.S_ISREG(info.st_mode):
                continue
            if now - info.st_mtime > FAVICON_CACHE_TTL_SECONDS:
                path.unlink(missing_ok=True)
                continue
            entries.append((info.st_atime, info.st_size, path))
        entries.sort()
        total_size = sum(size for _, size, _ in entries)
        while entries and (
            len(entries) > MAX_FAVICON_CACHE_ENTRIES or total_size > MAX_FAVICON_CACHE_BYTES
        ):
            _, size, path = entries.pop(0)
            path.unlink(missing_ok=True)
            total_size -= size

    def _fill(self, url):
        try:
            content_type, data = self._fetch(url)
            self._store(url, content_type, data)
        except Exception:
            # Cache failures must not affect native-messaging responses.
            pass
        finally:
            with self.lock:
                self.in_flight.discard(url)

    def schedule(self, url):
        canonical_url = canonical_favicon_url(url)
        if canonical_url is None:
            return
        with self.lock:
            if canonical_url in self.in_flight:
                return
            if self._get_canonical(canonical_url) is not None:
                return
            if len(self.in_flight) >= MAX_FAVICON_WORK_ITEMS:
                return
            self.in_flight.add(canonical_url)
            try:
                self.executor.submit(self._fill, canonical_url)
            except RuntimeError:
                self.in_flight.discard(canonical_url)

    def enrich_tabs(self, tabs):
        enriched_tabs = []
        for tab in tabs:
            enriched = dict(tab)
            cached = self.get(tab.get("favIconUrl"))
            if cached is not None:
                enriched["iconPath"] = str(cached)
            else:
                self.schedule(tab.get("favIconUrl"))
            enriched_tabs.append(enriched)
        return enriched_tabs


def read_exact(stream, size):
    chunks = []
    remaining = size
    while remaining:
        chunk = stream.read(remaining)
        if not chunk:
            return None
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def read_native_message(stream):
    header = read_exact(stream, 4)
    if header is None:
        return None
    (size,) = struct.unpack("<I", header)
    if size > MAX_MESSAGE_BYTES:
        raise ValueError("native message exceeds maximum size")
    payload = read_exact(stream, size)
    if payload is None:
        return None
    return json.loads(payload.decode("utf-8"))


def write_native_message(message):
    payload = json.dumps(message, separators=(",", ":")).encode("utf-8")
    if len(payload) > MAX_MESSAGE_BYTES:
        raise ValueError("native message exceeds maximum size")
    sys.stdout.buffer.write(struct.pack("<I", len(payload)))
    sys.stdout.buffer.write(payload)
    sys.stdout.buffer.flush()


def send_client_message(connection, message):
    payload = json.dumps(message, separators=(",", ":")).encode("utf-8")
    if len(payload) > MAX_MESSAGE_BYTES:
        raise ValueError("client message exceeds maximum size")
    connection.sendall(payload + b"\n")


def read_client_response(connection):
    response = bytearray()
    while not response.endswith(b"\n"):
        chunk = connection.recv(4096)
        if not chunk:
            raise RuntimeError("browser tab bridge closed without a response")
        response.extend(chunk)
        if len(response) > MAX_MESSAGE_BYTES:
            raise RuntimeError("browser tab bridge response exceeds maximum size")
    try:
        message = json.loads(response[:-1].decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise RuntimeError(f"invalid browser tab bridge response: {error}") from error
    if not isinstance(message, dict) or not isinstance(message.get("ok"), bool):
        raise RuntimeError("invalid browser tab bridge response")
    return message


def request_client(request):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(3)
        connection.connect(str(socket_path()))
        send_client_message(connection, request)
        return read_client_response(connection)


def require_success(message):
    if not message["ok"]:
        error = message.get("error")
        if not isinstance(error, str):
            error = "browser tab bridge rejected the request"
        raise RuntimeError(error)


def request_url(url):
    if not valid_url(url):
        raise ValueError("only http(s) URLs are supported")
    message = request_client({"action": "focus-existing", "url": url})
    require_success(message)
    if message.get("action") != "focused":
        raise RuntimeError("invalid focus-existing response")


def request_tabs():
    message = request_client({"action": "list-tabs"})
    require_success(message)
    tabs = message.get("tabs")
    if not isinstance(tabs, list):
        raise RuntimeError("invalid list-tabs response")
    return tabs


def activate_tab(tab_id):
    message = request_client({"action": "activate-tab", "tabId": tab_id})
    require_success(message)
    if message.get("action") != "activated":
        raise RuntimeError("invalid activate-tab response")


def run_client(url):
    try:
        request_url(url)
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as error:
        print(f"windows-manager-linux-orgm-tab: {error}", file=sys.stderr)
        return 1
    return 0


def run_tabs_client(arguments):
    try:
        if arguments == ["list"]:
            print(json.dumps(request_tabs(), separators=(",", ":")))
        elif (
            len(arguments) == 2
            and arguments[0] == "activate"
            and re.fullmatch(r"[1-9][0-9]*", arguments[1])
        ):
            tab_id = int(arguments[1])
            activate_tab(tab_id)
        else:
            raise ValueError("usage: windows-manager-linux-orgm-tabs list|activate TAB_ID")
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as error:
        print(f"windows-manager-linux-orgm-tabs: {error}", file=sys.stderr)
        return 1
    return 0


def valid_tab_descriptor(tab):
    required = {"id", "windowId", "index", "active"}
    optional = {"title", "url", "favIconUrl"}
    if not isinstance(tab, dict) or not required.issubset(tab) or not set(tab).issubset(required | optional):
        return False
    if (
        not isinstance(tab["id"], int)
        or isinstance(tab["id"], bool)
        or tab["id"] <= 0
        or not isinstance(tab["windowId"], int)
        or isinstance(tab["windowId"], bool)
        or tab["windowId"] <= 0
        or not isinstance(tab["index"], int)
        or isinstance(tab["index"], bool)
        or tab["index"] < 0
        or not isinstance(tab["active"], bool)
    ):
        return False
    return all(isinstance(tab[key], str) and tab[key] for key in optional if key in tab)


def valid_tab_id(tab_id):
    return isinstance(tab_id, int) and not isinstance(tab_id, bool) and tab_id > 0


def validate_client_request(request):
    if not isinstance(request, dict):
        raise ValueError("request must be an object")

    action = request.get("action")
    if action == "focus-existing":
        if set(request) != {"action", "url"}:
            raise ValueError("invalid focus-existing request")
        url = request["url"]
        if not isinstance(url, str) or not valid_url(url):
            raise ValueError("only http(s) URLs are supported")
        return {"type": "focus-existing", "url": url}, action

    if action == "list-tabs":
        if set(request) != {"action"}:
            raise ValueError("invalid list-tabs request")
        return {"type": "tab-operation", "action": action}, action

    if action == "activate-tab":
        if set(request) != {"action", "tabId"}:
            raise ValueError("invalid activate-tab request")
        tab_id = request["tabId"]
        if not valid_tab_id(tab_id):
            raise ValueError("tabId must be a positive integer")
        return {"type": "tab-operation", "action": action, "tabId": tab_id}, action

    raise ValueError("unsupported request action")


def valid_browser_response(message, action):
    if not isinstance(message, dict) or not isinstance(message.get("ok"), bool):
        return False
    if message["ok"]:
        if action == "focus-existing":
            return set(message) == {"id", "ok", "action"} and message["action"] == "focused"
        if action == "list-tabs":
            return (
                set(message) == {"id", "ok", "tabs"}
                and isinstance(message["tabs"], list)
                and all(valid_tab_descriptor(tab) for tab in message["tabs"])
            )
        if action == "activate-tab":
            return set(message) == {"id", "ok", "action"} and message["action"] == "activated"
    return set(message) == {"id", "ok", "error"} and isinstance(message.get("error"), str)


def bounded_list_tabs_response(message, favicon_cache):
    response = {"id": message["id"], "ok": True, "tabs": []}
    for tab in favicon_cache.enrich_tabs(message["tabs"]):
        tab_without_icon = dict(tab)
        icon_path = tab_without_icon.pop("iconPath", None)
        candidate = dict(tab_without_icon)
        if icon_path is not None:
            candidate["iconPath"] = icon_path
            if len(json.dumps({**response, "tabs": response["tabs"] + [candidate]}, separators=(",", ":")).encode("utf-8")) > MAX_MESSAGE_BYTES:
                candidate.pop("iconPath")
        if len(json.dumps({**response, "tabs": response["tabs"] + [candidate]}, separators=(",", ":")).encode("utf-8")) > MAX_MESSAGE_BYTES:
            raise ValueError("list-tabs response exceeds maximum size")
        response["tabs"].append(candidate)
    return response


class NativeHost:
    def __init__(self):
        self.selector = selectors.DefaultSelector()
        self.pending = {}
        self.buffers = {}
        self.listener = None
        self.path = socket_path()
        self.favicon_cache = FaviconCache()

    def start_listener(self):
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        self.listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.listener.bind(str(self.path))
        self.path.chmod(0o600)
        self.listener.listen()
        self.listener.setblocking(False)
        self.selector.register(self.listener, selectors.EVENT_READ, self.accept_client)
        self.selector.register(sys.stdin.buffer, selectors.EVENT_READ, self.read_browser_message)

    def accept_client(self, listener):
        connection, _ = listener.accept()
        connection.setblocking(False)
        self.buffers[connection] = bytearray()
        self.selector.register(connection, selectors.EVENT_READ, self.read_client_message)

    def close_client(self, connection):
        self.pending = {
            key: value for key, value in self.pending.items() if value[0] is not connection
        }
        self.buffers.pop(connection, None)
        try:
            self.selector.unregister(connection)
        except KeyError:
            pass
        connection.close()

    def read_client_message(self, connection):
        chunk = connection.recv(4096)
        if not chunk:
            self.close_client(connection)
            return
        buffer = self.buffers[connection]
        buffer.extend(chunk)
        if len(buffer) > MAX_MESSAGE_BYTES:
            send_client_message(connection, {"ok": False, "error": "request exceeds maximum size"})
            self.close_client(connection)
            return
        if b"\n" not in buffer:
            return
        raw_message, _, remaining = buffer.partition(b"\n")
        try:
            if remaining:
                raise ValueError("request must contain exactly one message")
            request = json.loads(raw_message.decode("utf-8"))
            browser_request, action = validate_client_request(request)
        except (UnicodeDecodeError, ValueError, json.JSONDecodeError) as error:
            send_client_message(connection, {"ok": False, "error": str(error)})
            self.close_client(connection)
            return
        request_id = str(uuid.uuid4())
        self.pending[request_id] = (connection, action)
        browser_request["id"] = request_id
        write_native_message(browser_request)

    def read_browser_message(self, _):
        message = read_native_message(sys.stdin.buffer)
        if message is None:
            raise EOFError
        if not isinstance(message, dict) or not isinstance(message.get("id"), str):
            return
        request_id = message["id"]
        pending = self.pending.pop(request_id, None)
        if pending is None:
            return
        connection, action = pending
        try:
            if valid_browser_response(message, action):
                if action == "list-tabs":
                    message = bounded_list_tabs_response(message, self.favicon_cache)
                send_client_message(connection, message)
            else:
                send_client_message(connection, {
                    "id": request_id,
                    "ok": False,
                    "error": "invalid browser tab bridge response",
                })
        except ValueError as error:
            send_client_message(connection, {"id": request_id, "ok": False, "error": str(error)})
        finally:
            self.close_client(connection)

    def run(self):
        self.start_listener()
        try:
            while True:
                for key, _ in self.selector.select():
                    key.data(key.fileobj)
        except EOFError:
            return
        finally:
            self.selector.close()
            if self.listener is not None:
                self.listener.close()
            self.favicon_cache.close()
            try:
                self.path.unlink()
            except FileNotFoundError:
                pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--client", metavar="URL")
    parser.add_argument("--tabs-client", nargs="+", metavar="COMMAND")
    args = parser.parse_args()
    if args.client is not None:
        return run_client(args.client)
    if args.tabs_client is not None:
        return run_tabs_client(args.tabs_client)
    NativeHost().run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
