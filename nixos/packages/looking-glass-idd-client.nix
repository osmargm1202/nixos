{
  elfutils,
  fetchFromGitHub,
  libunwind,
  looking-glass-client,
}:

looking-glass-client.overrideAttrs (old: {
  version = "B7-544-d3fff4eb";

  src = fetchFromGitHub {
    owner = "gnif";
    repo = "LookingGlass";
    rev = "d3fff4eb571b92e372bff859537bdbeafdbcd7f4";
    hash = "sha256-2VyAGd63aPJ3XzE7Djj1LzfGf4MCSqW0V7h/85i0SGE=";
    fetchSubmodules = true;
  };

  buildInputs = old.buildInputs ++ [ elfutils libunwind ];

  postUnpack = ''
    echo d3fff4eb571b92e372bff859537bdbeafdbcd7f4 > source/VERSION
    export sourceRoot="source/client"
  '';
})
