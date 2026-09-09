{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs_22,
}:

stdenvNoCC.mkDerivation {
  pname = "orgm-organize";
  version = "1.1.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/orgm-organize/-/orgm-organize-1.1.0.tgz";
    hash = "sha512-wKuD3rq2qPbCX18zDhyUGWtIWWXYDF57Nq4OZJhtXJ3zJmMKRel6o2ujyC7Ijp7Hn8f3H0QF0Q3pG5ShCEhpHQ==";
  };

  sourceRoot = "package";
  dontBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -d "$out/lib/node_modules/orgm-organize"
    cp -r bin src package.json README.md LICENSE "$out/lib/node_modules/orgm-organize/"
    makeWrapper ${nodejs_22}/bin/node "$out/bin/orgm-organize" \
      --add-flags "$out/lib/node_modules/orgm-organize/bin/orgm-organize.js"
    runHook postInstall
  '';

  meta = {
    description = "Safely organize files by date and extension hierarchies";
    homepage = "https://github.com/osmargm1202/orgm-organize";
    license = lib.licenses.mit;
    mainProgram = "orgm-organize";
    platforms = lib.platforms.linux;
  };
}
