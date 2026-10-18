# Canonical systems select one desktop per physical host.
let
  historical = import ./configurations-legacy.nix;
in
{
  inherit (historical) profiles;
  aliases = { };
  configurations = {
    envy = historical.configurations.envy;
    lenovo = historical.configurations.lenovo-ryoku;
    orgm = historical.configurations.orgm-ryoku;
    ero = historical.configurations.ero-i3;
    jarq = historical.configurations.jarq-i3;
  };
}
