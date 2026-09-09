{
  lib,
  stdenv,
  buildNpmPackage,
  fetchurl,
  nodejs_22,
  jq,
  autoPatchelfHook,
  makeWrapper,
  libx11,
  xsel,
  wl-clipboard,
}:

let
  # DuckDB publishes this binding for Node 22 (ABI 127). Fetch it explicitly
  # rather than letting node-pre-gyp access the network during installation.
  duckdbBinding = fetchurl {
    url = "https://npm.duckdb.org/duckdb/duckdb-v1.4.4-node-v127-linux-x64.tar.gz";
    hash = "sha256-gY2SoAVykcmcBENvy+e6+1TUwj/lw/mvwgs768B/5oA=";
  };
in
buildNpmPackage {
  pname = "orgmrnc";
  version = "0.1.6";
  nodejs = nodejs_22;

  src = fetchurl {
    url = "https://registry.npmjs.org/orgmrnc/-/orgmrnc-0.1.6.tgz";
    hash = "sha512-spyzppF9/U4bbE6rwG71BLl5e0KsK2/Y+VYNsvidO5aCQmwjt2GBgfY/9Weby5EHuH8xE+AcJFUSaRpuGezckA==";
  };

  npmDepsHash = "sha256-pMcuTvcVHIzbZR63tUxA6J0pWyCc1CI7uWpKSpIDL9A=";
  # The published package includes the compiled ESM application. Its source
  # development tools and prepublish hook are not needed by the runtime.
  postPatch = ''
    ${lib.getExe jq} 'del(.devDependencies, .scripts)' package.json > package.json.tmp
    mv package.json.tmp package.json
    cp ${./orgm-rnc-package-lock.json} package-lock.json
  '';
  dontNpmBuild = true;
  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    libx11
  ];

  postInstall = ''
    binding_dir="$out/lib/node_modules/orgmrnc/node_modules/duckdb/lib/binding"
    mkdir -p "$binding_dir"
    tar -xzf ${duckdbBinding} --strip-components=1 -C "$binding_dir"
  '';

  postFixup = ''
    wrapProgram "$out/bin/orgmrnc" \
      --prefix PATH : ${
        lib.makeBinPath [
          xsel
          wl-clipboard
        ]
      }
  '';

  meta = {
    description = "Terminal RNC lookup backed by DuckDB";
    homepage = "https://github.com/osmargm1202/orgmrnc";
    mainProgram = "orgmrnc";
    platforms = [ "x86_64-linux" ];
  };
}
