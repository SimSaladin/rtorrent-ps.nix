lib: _lprev:

{
  isGenericSystem = sys:
    (sys.isx86_64 && sys.gcc ? arch) -> sys.gcc.arch == "x86-64" || sys.gcc.arch == "generic";

  makeGenericSystem = sys:
    if sys.isx86_64 then lib.systems.elaborate sys.system else sys;

  versionToName = lib.replaceStrings [ "." ] [ "_" ];

  mapSuffix = suf: lib.mapAttrs' (k: v: {
    name = if lib.isDerivation v then
      lib.versionToName (k + "/" + suf)
    else k;
    value = v;
  });
}
