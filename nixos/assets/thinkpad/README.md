# ThinkPad boot fallback

`thinkpad.svg` is Lenovo's ThinkPad text logo, retrieved from
https://upload.wikimedia.org/wikipedia/commons/0/09/ThinkPad_Logo.svg on 2026-10-28.
Source and author: Lenovo Group Limited, according to
https://commons.wikimedia.org/wiki/File:ThinkPad_Logo.svg (2020-05-11 revision).
The Commons description classifies this simple text logo as public domain;
ThinkPad remains a Lenovo trademark.

The Plymouth package renders the original vector with white lettering and its
red dot, at 320 pixels wide on black. It only supplies `bgrt-fallback.png`:
Plymouth's existing BGRT plugin gives a firmware-provided image priority. The
spinner and the NixOS watermark retain the stock theme's layout and animation.
