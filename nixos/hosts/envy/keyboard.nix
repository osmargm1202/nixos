{ ... }:
{
  # The built-in Up key is physically stuck. Ignore its scan code in the
  # kernel, before it can pollute compositor shortcut state. USB keyboards
  # and other laptop models do not match this record.
  services.udev.extraHwdb = ''
    evdev:atkbd:dmi:*:svnHP:pnHPENVYLaptop17m-ce1xxx:*
     KEYBOARD_KEY_c8=reserved
  '';
}
