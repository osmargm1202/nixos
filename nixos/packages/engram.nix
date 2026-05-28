{ lib, buildGoModule, fetchFromGitHub, git }:

buildGoModule {
  pname = "engram";
  version = "unstable-2026-05-28";

  src = fetchFromGitHub {
    owner = "Gentleman-Programming";
    repo = "engram";
    rev = "main";
    hash = "sha256-e0gjrUhO/5JpcUntbZJ2QasfSP2hP1N7RvRE4vBl5eE=";
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
