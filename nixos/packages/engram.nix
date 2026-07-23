{
  lib,
  buildGoModule,
  fetchFromGitHub,
  gitMinimal,
}:

buildGoModule rec {
  pname = "engram";
  version = "1.20.0";

  src = fetchFromGitHub {
    owner = "Gentleman-Programming";
    repo = "engram";
    rev = "v${version}";
    hash = "sha256-qdKAll7N0HtJRbZYilzatVCUz1Tr+pqM217Y8O+Csjs=";
  };

  subPackages = [ "cmd/engram" ];
  vendorHash = "sha256-O+pC4x4DKNUWr7Sx9iZOjK6a64wrQA4/lnjvkNLBX64=";
  nativeCheckInputs = [ gitMinimal ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  meta = {
    description = "Persistent memory system for AI coding agents";
    homepage = "https://github.com/Gentleman-Programming/engram";
    license = lib.licenses.mit;
    mainProgram = "engram";
  };
}
