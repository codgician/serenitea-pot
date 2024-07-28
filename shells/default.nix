args @ { lib, pkgs, inputs, outputs, ... }:
let
  system = pkgs.system;
  basePkgs = [ inputs.agenix.packages.${system}.default ];
  shellNames = lib.codgician.getFolderNames ./.;
in
builtins.listToAttrs (builtins.map
  (name: {
    inherit name;
    value = import ./${name} (args // { inherit basePkgs; });
  })
  shellNames)
