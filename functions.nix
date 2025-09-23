lib: _lprev:

{
  isGenericSystem = sys:
    (sys.isx86_64 && sys.gcc ? arch) -> sys.gcc.arch == "x86-64" || sys.gcc.arch == "generic";

  makeGenericSystem = sys:
    if sys.isx86_64 then lib.systems.elaborate sys.system else sys;

  versionToName = lib.replaceStrings [ "." ] [ "_" ];

  mapSuffix = suf: lib.mapAttrs' (name: value: {
    name = if lib.isDerivation value then lib.versionToName (name + "/" + suf) else name;
    inherit value;
  });
}
