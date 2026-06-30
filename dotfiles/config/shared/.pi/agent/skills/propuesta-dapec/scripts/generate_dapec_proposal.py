#!/usr/bin/env python3
"""Generate a DAPEC SRL branded printable HTML proposal from numbered Markdown."""
from __future__ import annotations

import argparse
import html
import re
from pathlib import Path

BRAND = {
    "navy": "#071827",
    "blue": "#0b3345",
    "accent": "#07859a",
    "ink": "#162232",
    "muted": "#607080",
    "paper": "#ffffff",
    "wash": "#e7edf2",
}

COMPANY_FULL = "DISEÑO Y ASESORIA DE PROYECTOS ELECTROMECANICOS Y CIVILES DAPEC SRL"
RNC = "131351247"
DEFAULT_LOGO_URL = "dapec_orgm.png"


def inline_md(text: str) -> str:
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"\*(.+?)\*", r"<em>\1</em>", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    return text


def render_blocks(md: str) -> str:
    lines = md.splitlines()
    out: list[str] = []
    in_ul = in_ol = False
    in_table = False

    def close_lists():
        nonlocal in_ul, in_ol
        if in_ul:
            out.append("</ul>")
            in_ul = False
        if in_ol:
            out.append("</ol>")
            in_ol = False

    def close_table():
        nonlocal in_table
        if in_table:
            out.append("</tbody></table>")
            in_table = False

    i = 0
    while i < len(lines):
        raw = lines[i]
        line = raw.strip()
        if not line:
            close_lists(); close_table(); i += 1; continue
        if line.startswith("### "):
            close_lists(); close_table(); out.append(f"<h3>{inline_md(line[4:])}</h3>"); i += 1; continue
        if line.startswith("## "):
            close_lists(); close_table(); out.append(f"<h3>{inline_md(line[3:])}</h3>"); i += 1; continue
        if line.startswith("# "):
            close_lists(); close_table(); out.append(f"<h2>{inline_md(line[2:])}</h2>"); i += 1; continue
        if re.match(r"^[-*]\s+", line):
            close_table()
            if not in_ul:
                close_lists(); out.append("<ul>"); in_ul = True
            out.append(f"<li>{inline_md(re.sub(r'^[-*]\s+', '', line))}</li>"); i += 1; continue
        if re.match(r"^\d+\.\s+", line):
            close_table()
            if not in_ol:
                close_lists(); out.append("<ol>"); in_ol = True
            out.append(f"<li>{inline_md(re.sub(r'^\d+\.\s+', '', line))}</li>"); i += 1; continue
        if "|" in line and line.startswith("|") and line.endswith("|"):
            close_lists()
            cells = [c.strip() for c in line.strip("|").split("|")]
            next_line = lines[i + 1].strip() if i + 1 < len(lines) else ""
            if not in_table:
                out.append("<table>")
                if re.match(r"^\|?\s*:?-{3,}:?", next_line):
                    out.append("<thead><tr>" + "".join(f"<th>{inline_md(c)}</th>" for c in cells) + "</tr></thead><tbody>")
                    in_table = True
                    i += 2
                    continue
                out.append("<tbody>")
                in_table = True
            out.append("<tr>" + "".join(f"<td>{inline_md(c)}</td>" for c in cells) + "</tr>")
            i += 1; continue
        close_lists(); close_table()
        out.append(f"<p>{inline_md(line)}</p>")
        i += 1
    close_lists(); close_table()
    return "\n".join(out)


def split_sections(md: str) -> list[tuple[str, str]]:
    matches = list(re.finditer(r"(?m)^#\s+(.+)$", md))
    if not matches:
        return [("Propuesta", md)]
    sections = []
    for idx, m in enumerate(matches):
        start = m.start()
        end = matches[idx + 1].start() if idx + 1 < len(matches) else len(md)
        block = md[start:end].strip()
        title = m.group(1).strip()
        sections.append((title, block))
    return sections


def parse_layout(layout: str | None, count: int) -> list[list[int]]:
    if not layout:
        return [[i] for i in range(1, count + 1)]
    groups = []
    for group in layout.split("|"):
        nums = [int(x.strip()) for x in group.split(",") if x.strip()]
        if nums:
            groups.append(nums)
    return groups or [[i] for i in range(1, count + 1)]


def build_html(args: argparse.Namespace) -> str:
    md = Path(args.input).read_text(encoding="utf-8")
    sections = split_sections(md)
    groups = parse_layout(args.layout, len(sections))
    styles = f"""
    @page{{size:letter;margin:0}}*{{box-sizing:border-box}}body{{margin:0;background:{BRAND['wash']};color:{BRAND['ink']};font-family:Arial,Helvetica,sans-serif;line-height:1.38}}.sheet{{width:8.5in;min-height:11in;margin:18px auto;background:{BRAND['paper']};position:relative;padding:.65in .7in .72in;box-shadow:0 8px 30px rgba(0,0,0,.14);page-break-after:always;overflow:hidden}}.cover{{display:flex;flex-direction:column;justify-content:space-between;color:{BRAND['ink']};background:linear-gradient(135deg,#ffffff 0%,#f4fbfc 55%,{BRAND['wash']} 100%);border-top:12px solid {BRAND['accent']};padding:.72in}}.logo{{max-width:2.25in;max-height:1.15in;object-fit:contain}}.small-logo{{max-width:.92in;max-height:.42in;object-fit:contain}}.brand-row{{display:flex;align-items:center;gap:14px}}.mark{{font-size:34px;font-weight:800;letter-spacing:1px;border:2px solid rgba(255,255,255,.7);display:inline-block;padding:10px 14px}}.kicker{{margin-top:1.15in;color:{BRAND['accent']};font-size:12px;letter-spacing:2.8px;text-transform:uppercase;font-weight:700}}h1{{font-size:38px;line-height:1.05;margin:16px 0 10px;max-width:6.4in}}.subtitle{{font-size:16px;max-width:6in;color:{BRAND['blue']}}}.cover-meta{{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-top:.45in;font-size:12px;color:{BRAND['ink']}}}.meta-box{{border-top:1px solid #b7d8de;padding-top:9px}}.topbar{{display:flex;align-items:center;justify-content:space-between;border-bottom:2px solid {BRAND['accent']};padding-bottom:12px;margin-bottom:22px;color:{BRAND['muted']};font-size:10.5px;text-transform:uppercase;letter-spacing:1px}}.mini-mark{{font-size:18px;font-weight:800;color:{BRAND['navy']}}}h2{{font-size:22px;color:{BRAND['navy']};margin:0 0 12px;border-left:6px solid {BRAND['accent']};padding-left:12px}}h3{{font-size:15px;color:{BRAND['blue']};margin:16px 0 7px}}p{{margin:0 0 10px}}ul,ol{{margin:7px 0 13px 22px;padding:0}}li{{margin:5px 0}}table{{width:100%;border-collapse:collapse;margin:12px 0 16px;font-size:12.3px}}th{{background:{BRAND['navy']};color:#fff;text-align:left}}th,td{{border:1px solid #cfd9df;padding:8px;vertical-align:top}}.footer{{position:absolute;left:.7in;right:.7in;bottom:.34in;border-top:1px solid #dbe3e8;padding-top:8px;display:flex;justify-content:space-between;color:{BRAND['muted']};font-size:10px}}@media print{{body{{background:#fff}}.sheet{{margin:0;box-shadow:none;min-height:11in}}}}
    """
    cover = f"""
    <section class="sheet cover">
      <div><div class="brand-row"><img class="logo" src="{html.escape(args.logo_url)}" alt="DAPEC SRL"></div><div class="kicker">Propuesta de Servicio</div><h1>{html.escape(args.title)}</h1><div class="subtitle">{html.escape(args.subtitle)}</div></div>
      <div class="cover-meta"><div class="meta-box"><strong>Cliente</strong><br>{html.escape(args.client)}</div><div class="meta-box"><strong>Proponente</strong><br>DAPEC SRL<br>RNC {RNC}</div><div class="meta-box"><strong>Fecha</strong><br>{html.escape(args.date)}</div><div class="meta-box"><strong>Validez</strong><br>{html.escape(args.validity)}</div></div>
    </section>
    """
    pages = []
    for page_no, group in enumerate(groups, start=1):
        content = []
        for n in group:
            if 1 <= n <= len(sections):
                content.append(render_blocks(sections[n-1][1]))
        pages.append(f"""<section class="sheet"><div class="topbar"><span class="brand-row"><img class="small-logo" src="{html.escape(args.logo_url)}" alt="DAPEC SRL"><span class="mini-mark">DAPEC SRL</span></span><span>{html.escape(args.proposal_name)}</span></div>{''.join(content)}<div class="footer"><span>{html.escape(args.proposal_name)}</span><span>DAPEC SRL · RNC {RNC} · Página {page_no}</span></div></section>""")
    return f"<!doctype html><html lang=\"es\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>{html.escape(args.title)}</title><style>{styles}</style></head><body>{cover}{''.join(pages)}</body></html>"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, help="Numbered Markdown proposal source")
    parser.add_argument("--output", required=True, help="Output HTML path")
    parser.add_argument("--layout", default="1,2|3|4|5,6|7,8,9,10", help="Section groups per sheet, e.g. '1,2|3|4,5'")
    parser.add_argument("--proposal-name", default="Propuesta de Servicio")
    parser.add_argument("--title", default="Propuesta de Servicio")
    parser.add_argument("--subtitle", default="Diseño y Asesoría de Proyectos Electromecánicos y Civiles")
    parser.add_argument("--client", default="[Cliente]")
    parser.add_argument("--date", default="[Fecha]")
    parser.add_argument("--validity", default="[Vigencia]")
    parser.add_argument("--logo-url", default=DEFAULT_LOGO_URL, help="Main DAPEC logo URL or file path")
    args = parser.parse_args()
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(build_html(args), encoding="utf-8")
    print(f"Wrote {output}")


if __name__ == "__main__":
    main()
