# One public system per physical host. Alternative desktop files remain available
# internally, but selecting a host must not merge those alternative profiles.
let
  historical = import ./configurations-legacy.nix;
in
{
  inherit (historical) profiles;
  aliases = { };
  configurations = {
    envy = historical.configurations.envy-ryoku;
    lenovo = historical.configurations.lenovo-ryoku;
    orgm = historical.configurations.orgm-ryoku;
    ero = historical.configurations.ero-i3;
    jarq = historical.configurations.jarq-i3;
  };
}
