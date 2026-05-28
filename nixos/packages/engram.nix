{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule {
  pname = "engram";
  version = "unstable-2026-05-28";

  src = fetchFromGitHub {
    owner = "Gentleman-Programming";
    repo = "engram";
    rev = "main";
    hash = lib.fakeHash;
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
