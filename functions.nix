_lfinal: _lprev:

{
  isGenericSystem = sys:
    ((sys.isx86_64 && sys.gcc ? arch) -> sys.gcc.arch == "x86-64");

  makeGenericSystem = sys:
    if sys.isx86_64 then sys // { gcc = builtins.removeAttrs sys.gcc [ "arch" "tune" ]; } else sys;
}
