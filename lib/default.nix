args @ { lib, ... }:

let
  # Concat attributes
  concatAttrs = attrList: builtins.foldl' (x: y: x // y) { } attrList;

  # Extend lib with custom functions
  mkMyLib = { lib }: concatAttrs
    (builtins.map (x: import x (args // { inherit lib; })) [
      ./consts.nix
      ./io.nix
      ./secrets.nix
      ./utils.nix
    ]) // { inherit concatAttrs; };
in
lib.extend (self: super: { codgician = mkMyLib { lib = self; }; })
