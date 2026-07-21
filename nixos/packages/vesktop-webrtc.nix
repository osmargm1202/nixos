{
  symlinkJoin,
  vesktop,
  makeWrapper,
}:

symlinkJoin {
  name = "vesktop-webrtc-${vesktop.version}";
  paths = [ vesktop ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram "$out/bin/vesktop" \
      --add-flags "--force-webrtc-ip-handling-policy=default_public_and_private_interfaces"
  '';
  meta.mainProgram = "vesktop";
}
