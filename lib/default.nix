{ nixpkgs, ... }:
let
  lib = nixpkgs.lib;
  concatAttrs = (import ./misc.nix).concatAttrs;
in
rec {
  codgician = concatAttrs [
    (import ./misc.nix)
    (import ./secrets.nix { inherit lib codgician; })
  ];
}
