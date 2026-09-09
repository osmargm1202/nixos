{
  lib,
  buildGoModule,
  makeWrapper,
  gum,
}:

buildGoModule {
  pname = "orgmai";
  version = "0.2.2";
  # Snapshot of ~/Code/orgm-ai; no host-specific paths or network Go dependencies.
  src = ../ai/orgmai-src;
  vendorHash = null;
  subPackages = [ "cmd/orgmai" ];
  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram "$out/bin/orgmai" \
      --prefix PATH : ${lib.makeBinPath [ gum ]}
  '';

  meta = {
    description = "Quick persistent Gum chat powered by extension-free Pi";
    homepage = "https://github.com/osmargm1202/orgmai";
    mainProgram = "orgmai";
    platforms = lib.platforms.linux;
  };
}
