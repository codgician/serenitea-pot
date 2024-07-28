args @ { system, lib, pkgs, inputs, outputs, ... }:
let
  basePkgs = [ inputs.agenix.packages.${system}.default ];
  shellNames = lib.codgician.getFolderNames ./.;
in
builtins.listToAttrs (builtins.map
  (name: {
    inherit name;
    value = import ./${name} (args // { inherit basePkgs; });
  })
  shellNames)
