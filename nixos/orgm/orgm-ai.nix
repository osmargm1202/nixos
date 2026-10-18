{
  lib,
  buildGoModule,
  makeWrapper,
  gum,
}:

buildGoModule {
  pname = "orgmai";
  version = "0.4.1";
  # Thin native client launcher; no AI transport, model or credential handling.
  src = ./orgmai-src;
  vendorHash = null;
  subPackages = [ "cmd/orgmai" ];
  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram "$out/bin/orgmai" \
      --prefix PATH : ${lib.makeBinPath [ gum ]}
    ln -s orgmai "$out/bin/ai-chat"
  '';

  meta = {
    description = "Native launcher for Claude, Codex, OpenCode, OMP or Pi";
    homepage = "https://github.com/osmargm1202/orgmai";
    mainProgram = "orgmai";
    platforms = lib.platforms.linux;
  };
}
