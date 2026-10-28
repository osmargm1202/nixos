{ bun, fetchurl }:
# Same pinned runtime as Nixpkgs, using upstream's Linux SSE4.2 binary.
# No AVX/AVX2 and no local compilation on older x86_64 laptops.
bun.overrideAttrs (_: {
  pname = "bun-baseline";
  src = fetchurl {
    url = "https://github.com/oven-sh/bun/releases/download/bun-v1.3.13/bun-linux-x64-baseline.zip";
    sha256 = "9d8a24292a7068090205daac0a5a223f5f69736f5287e37bf88d3b4031edc750";
  };
  sourceRoot = "bun-linux-x64-baseline";
})
