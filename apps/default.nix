args @ { lib, pkgs, inputs, outputs, ... }:
let
  appNames = lib.codgician.getFolderNames ./.;
in
builtins.listToAttrs (builtins.map
  (name: {
    inherit name;
    value = import ./${name} args;
  })
  appNames)
