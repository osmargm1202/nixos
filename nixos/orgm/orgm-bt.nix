{
  lib,
  fontconfig,
  python3Packages,
}:

let
  inherit (python3Packages)
    alembic
    boto3
    buildPythonApplication
    coloraide
    customtkinter
    fastapi
    fetchPypi
    hsluv
    jinja2
    pandas
    pillow
    pydantic-settings
    psycopg2
    python-dotenv
    python-multipart
    questionary
    reportlab
    requests
    rich
    setuptools
    sqlmodel
    tabulate
    tkinter
    uvicorn
    weasyprint
    webdav4
    ;
  nocodb = python3Packages.callPackage ./python/nocodb.nix { };
in
buildPythonApplication rec {
  pname = "orgm-bt";
  version = "0.4.0";
  pyproject = true;

  src = fetchPypi {
    pname = "orgm_bt";
    inherit version;
    hash = "sha256-rgYiakVsDf6IPExvBcYwaw5tsGDgD8e+4ithi43wYoY=";
  };

  build-system = [ setuptools ];

  # The source-built Nix package exposes the same psycopg2 module without
  # bundling a second copy of libpq; keep the runtime dependency check enabled.
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'psycopg2-binary>=2.9.9' 'psycopg2>=2.9.9'
  '';

  dependencies = [
    jinja2
    weasyprint
    pillow
    reportlab
    sqlmodel
    alembic
    # Nix builds psycopg2 against libpq instead of using PyPI's binary wheel.
    psycopg2
    pydantic-settings
    fastapi
    uvicorn
    requests
    python-dotenv
    pandas
    boto3
    rich
    tabulate
    nocodb
    questionary
    coloraide
    hsluv
    python-multipart
    # CustomTkinter requires the separately packaged Tkinter extension at runtime.
    customtkinter
    tkinter
    webdav4
  ]
  # PyPI's uvicorn[standard] extra.
  ++ uvicorn.optional-dependencies.standard;

  # WeasyPrint is patched in nixpkgs with Nix-store paths for Pango, HarfBuzz,
  # and Fontconfig. Its CLI wrapper sets this variable; orgm-bt imports the
  # library directly, so retain the same font configuration for PDF generation.
  makeWrapperArgs = [
    "--set-default"
    "FONTCONFIG_FILE"
    "${fontconfig.out}/etc/fonts/fonts.conf"
  ];

  meta = {
    description = "CLI for low-voltage electrical calculations, panel schedules, and HTML/PDF reports";
    homepage = "https://github.com/osmargm1202/calc";
    mainProgram = "orgm-bt";
    platforms = lib.platforms.linux;
  };
}
