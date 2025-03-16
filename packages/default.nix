args@{ lib, ... }:

lib.codgician.forAllSystems (
  pkgs:
  let
    attrs = lib.pipe ./. [
      lib.codgician.getFolderNames
      (builtins.map (name: {
        inherit name;
        value = import ./${name} (args // { inherit pkgs; });
      }))
      builtins.listToAttrs
    ];
  in
  lib.filterAttrs (k: v: !(v.meta ? platforms) || (builtins.elem pkgs.system v.meta.platforms)) attrs
)
