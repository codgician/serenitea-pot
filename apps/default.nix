args @ { lib, ... }:
let names = lib.codgician.getFolderNames ./.;
in builtins.listToAttrs (builtins.map
  (name: {
    inherit name;
    value = import ./${name} args;
  })
  names)
