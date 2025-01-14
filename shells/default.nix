args@{ lib, pkgs, ... }:
let
  basePkgs = with pkgs; [ agenix ];
  shellNames = lib.codgician.getFolderNames ./.;
in
builtins.listToAttrs (
  builtins.map (name: {
    inherit name;
    value = import ./${name} (args // { inherit basePkgs; });
  }) shellNames
)
