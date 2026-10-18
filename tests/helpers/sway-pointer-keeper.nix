{ runCommandCC, wayland, wayland-scanner, wlrctl }:
runCommandCC "sway-test-pointer-keeper" {
  buildInputs = [ wayland ];
  nativeBuildInputs = [ wayland-scanner ];
} ''
  protocol=${wlrctl.src}/protocol/wlr-virtual-pointer-unstable-v1.xml
  wayland-scanner client-header "$protocol" virtual-pointer.h
  wayland-scanner private-code "$protocol" virtual-pointer.c
  mkdir -p "$out/bin"
  $CC -Wall -Wextra -I. ${./sway-pointer-keeper.c} virtual-pointer.c \
    -lwayland-client -lm -o "$out/bin/sway-test-pointer-keeper"
''
