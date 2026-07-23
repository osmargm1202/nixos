{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "rtk";
  version = "0.37.2";

  src = fetchFromGitHub {
    owner = "rtk-ai";
    repo = "rtk";
    rev = "80a6fe606f73b19e52b0b330d242e62a6c07be42";
    hash = "sha256-rNuu8B5TnKZHrbVSV8HkcTeTdcol26259GGJEPEMPZY=";
  };

  cargoHash = "sha256-61+PNuVF8H5+9PHc3MBt8V80ieBBi8HzSC9Gc/WUSzM=";

  # Several upstream tests require a writable user home for RTK's tracking
  # database and global hook fixtures; Nix builds intentionally use
  # /homeless-shelter.
  doCheck = false;

  meta = {
    description = "CLI proxy that reduces LLM token consumption";
    homepage = "https://github.com/rtk-ai/rtk";
    license = lib.licenses.asl20;
    mainProgram = "rtk";
  };
}
