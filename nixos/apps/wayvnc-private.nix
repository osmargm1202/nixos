{ pkgs }:
# Clipboard sharing is deliberately off in this session-sharing backend. Rapid
# reconnect with an existing selection kills upstream 0.10.0 with invalid
# data_offer IDs (covered by our private Sway regression). Keyboard/pointer and
# video capture remain enabled; no global WayVNC package is replaced.
pkgs.wayvnc.overrideAttrs (old: {
  pname = "orgm-wayvnc-private";
  postPatch = (old.postPatch or "") + ''
    substituteInPlace src/main.c --replace-fail \
      $'static void client_init_data_control(struct wayvnc_client* self)\n{' \
      $'static void client_init_data_control(struct wayvnc_client* self)\n{\n\t/* Private sharing: no clipboard bridge or data-control offers. */\n\treturn;'
  '';
})
