{
  lib,
  fetchFromGitHub,
  makeWrapper,
  python3Packages,
  stdenvNoCC,
}:

let
  python = python3Packages.python.withPackages (
    ps: with ps; [
      questionary
      rich
      typer
    ]
  );
in
stdenvNoCC.mkDerivation {
  pname = "orgm-todo";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "osmargm1202";
    repo = "orgm-todo";
    rev = "17cba1eed823359a02c566cd1b8f1dfd8e28aaa2";
    hash = "sha256-zmLu/FUt47p3DFhYmc2t61s0tV/MTTdlvFFya6qmVZs=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    packageDir="$out/${python.sitePackages}"
    install -d "$packageDir"
    cp -r src/orgm_todo "$packageDir/"
    makeWrapper "${python}/bin/python" "$out/bin/orgm-todo" \
      --prefix PYTHONPATH : "$packageDir" \
      --add-flags "-m orgm_todo.cli"
    "$out/bin/orgm-todo" --help >/dev/null
    install -Dm644 \
      <("$out/bin/orgm-todo" --show-completion bash) \
      "$out/share/bash-completion/completions/orgm-todo"
    runHook postInstall
  '';


  meta = {
    description = "CLI de seguimiento ORGM sobre un vault de Obsidian";
    homepage = "https://github.com/osmargm1202/orgm-todo";
    license = lib.licenses.unfree;
    mainProgram = "orgm-todo";
    platforms = lib.platforms.linux;
  };
}
