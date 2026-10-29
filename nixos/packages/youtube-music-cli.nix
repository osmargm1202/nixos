{ lib, stdenvNoCC, fetchurl, makeWrapper, nodejs_22, yt-dlp, mpv, mpvScripts, makeDesktopItem }:
let
  mpvWithMpris = mpv.override { scripts = [ mpvScripts.mpris ]; };
  desktop = makeDesktopItem {
    name = "orgm-youtube-music-cli";
    desktopName = "YouTube Music (terminal)";
    exec = "youtube-music-cli";
    icon = "audio-x-generic";
    categories = [ "AudioVideo" "Audio" "Player" ];
    terminal = true;
  };
in stdenvNoCC.mkDerivation {
  pname = "youtube-music-cli";
  version = "0.3.6";
  src = fetchurl {
    url = "https://registry.npmjs.org/@involvex/youtube-music-cli/-/youtube-music-cli-0.3.6.tgz";
    hash = "sha256-JVcnuLIUWR2nzcDLPhla8iNiXmMdJn/c5b/XjxS2X4o=";
  };
  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/youtube-music-cli" "$out/bin" "$out/share/applications"
    cp -r dist package.json LICENSE "$out/share/youtube-music-cli/"
    makeWrapper ${nodejs_22}/bin/node "$out/bin/youtube-music-cli" \
      --add-flags "$out/share/youtube-music-cli/dist/source/cli.js" \
      --prefix PATH : ${lib.makeBinPath [ mpvWithMpris yt-dlp nodejs_22 ]} \
      --set-default MPV_PATH ${mpvWithMpris}/bin/mpv
    ln -s youtube-music-cli "$out/bin/ymc"
    ln -s ${desktop}/share/applications/orgm-youtube-music-cli.desktop "$out/share/applications/"
    runHook postInstall
  '';
  passthru = { inherit mpvWithMpris; };
  meta = {
    description = "Terminal YouTube Music player with mpv and yt-dlp";
    homepage = "https://github.com/involvex/youtube-music-cli";
    license = lib.licenses.mit;
    mainProgram = "youtube-music-cli";
    platforms = lib.platforms.linux;
  };
}
