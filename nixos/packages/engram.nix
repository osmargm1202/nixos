{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule {
  pname = "engram";
  version = "unstable-2026-05-28";

  src = fetchFromGitHub {
    owner = "Gentleman-Programming";
    repo = "engram";
    rev = "main";
    hash = "sha256-e0gjrUhO/5JpcUntbZJ2QasfSP2hP1N7RvRE4vBl5eE=";
  };

  subPackages = [ "cmd/engram" ];
  vendorHash = lib.fakeHash;

  meta = {
    description = "Engram CLI";
    homepage = "https://github.com/Gentleman-Programming/engram";
    mainProgram = "engram";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
