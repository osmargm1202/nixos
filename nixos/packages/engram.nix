{ lib, buildGoModule, fetchFromGitHub, git }:

buildGoModule {
  pname = "engram";
  version = "unstable-2026-05-28";

  src = fetchFromGitHub {
    owner = "Gentleman-Programming";
    repo = "engram";
    rev = "07445ba99eac95083d7c6d56c5d795bb68e90834";
    hash = "sha256-q5X6W/6qkD0zisM1yo6MpU3PgbotRhygLsi/pc2ZeuE=";
  };

  postPatch = ''
    substituteInPlace go.mod \
      --replace-fail "go 1.25.10" "go 1.25.9"
  '';

  subPackages = [ "cmd/engram" ];
  vendorHash = "sha256-O+pC4x4DKNUWr7Sx9iZOjK6a64wrQA4/lnjvkNLBX64=";

  nativeCheckInputs = [ git ];

  meta = {
    description = "Engram CLI";
    homepage = "https://github.com/Gentleman-Programming/engram";
    mainProgram = "engram";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
