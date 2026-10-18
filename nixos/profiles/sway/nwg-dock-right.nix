{ nwg-dock }:

nwg-dock.overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [ ./nwg-dock-right.patch ];
})
