{ lib, ... }:

let
  # Concat attributes
  concatAttrs = attrList: builtins.foldl' (x: y: x // y) { } attrList;

  # Extend lib with custom functions
  mkMyLib = { lib }: concatAttrs [
    (import ./consts.nix { inherit lib; })
    (import ./misc.nix { inherit lib; })
    (import ./secrets.nix { inherit lib; })
    ({ inherit concatAttrs; })
  ];
in
lib.extend (self: super: {
  codgician = mkMyLib { lib = self; };
})
