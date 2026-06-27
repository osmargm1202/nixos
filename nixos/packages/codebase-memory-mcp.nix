{ lib, stdenvNoCC, fetchurl, autoPatchelfHook }:

stdenvNoCC.mkDerivation rec {
  pname = "codebase-memory-mcp";
  version = "0.8.1";

  src = fetchurl {
    url = "https://github.com/DeusData/codebase-memory-mcp/releases/download/v${version}/codebase-memory-mcp-linux-amd64.tar.gz";
    hash = "sha256-29O5Lqhw7yQLYwWfJr2hUBX3bvmXiTG+vDoPnQlHCXM=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 codebase-memory-mcp "$out/bin/codebase-memory-mcp"
    runHook postInstall
  '';

  meta = {
    description = "MCP server that builds a code knowledge graph for AI agents";
    homepage = "https://github.com/DeusData/codebase-memory-mcp";
    license = lib.licenses.mit;
    mainProgram = "codebase-memory-mcp";
    platforms = [ "x86_64-linux" ];
  };
}
