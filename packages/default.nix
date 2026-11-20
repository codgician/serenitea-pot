args@{ lib, pkgs, ... }:
let
  callPackage = lib.callPackageWith (pkgs // mypkgs);
  mypkgs = lib.pipe (builtins.readDir ./.) [
    (lib.filterAttrs (_: type: type == "directory"))
    (lib.mapAttrs (name: _: callPackage ./${name} args))
  ];
in
lib.filterAttrs (
  _: pkg: !(pkg.meta ? platforms) || builtins.elem pkgs.stdenv.hostPlatform.system pkg.meta.platforms
) mypkgs
