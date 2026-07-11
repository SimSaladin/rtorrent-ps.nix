lib: _lprev:

{
  versionToName = lib.replaceStrings [ "." ] [ "_" ];

  mapSuffix = suf: lib.mapAttrs' (name: value: {
    name = if lib.isDerivation value then lib.versionToName (name + "/" + suf) else name;
    inherit value;
  });
}
