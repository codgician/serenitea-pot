{ nixpkgs, ... }:
let
  lib = nixpkgs.lib;
  concatAttrs = attrList: builtins.foldl' (x: y: x // y) { } attrList;
in
rec {
  codgician = concatAttrs [
    (import ./misc.nix { inherit lib codgician; })
    (import ./secrets.nix { inherit lib codgician; })
  ];
}
