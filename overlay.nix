final: prev:

{
  lib = prev.lib.extend (import ./functions.nix);

  # C/C++: Force generic GCC to avoid segfaults with unstable features.
  pkgsGeneric =
    if prev ? pkgsGeneric then prev.pkgsGeneric else
    if final.lib.isGenericSystem final.stdenv.hostPlatform then final else
    import prev.path {
      inherit (final) config overlays;
      localSystem = final.lib.makeGenericSystem final.stdenv.hostPlatform;
    };

  rtorrentPS =
    let sources = final.callPackage ./sources.nix { }; in
    final.callPackage ./packages.nix { inherit sources; };
}
