lib: _lprev:

{
  isGenericSystem = sys:
    (sys.isx86_64 && sys.gcc ? arch) -> sys.gcc.arch == "x86-64" || sys.gcc.arch == "generic";

  makeGenericSystem = sys:
    if sys.isx86_64 then lib.systems.elaborate sys.system else sys;
}
