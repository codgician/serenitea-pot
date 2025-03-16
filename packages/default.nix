args@{ lib, pkgs, ... }:
let
  callPackage = lib.callPackageWith (pkgs // mypkgs);
  mypkgs = lib.pipe (builtins.readDir ./.) [
    (lib.filterAttrs (_: type: type == "directory"))
    (lib.mapAttrs (k: v: callPackage ./${k} args))
  ];
in
lib.filterAttrs (k: v: !(v.meta ? platforms) || (builtins.elem pkgs.system v.meta.platforms)) mypkgs
