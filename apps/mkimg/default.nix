args @ { lib, ... }:

lib.codgician.forAllSystems (pkgs: import ./cli.nix (args // { inherit pkgs; }))
