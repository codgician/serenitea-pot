args@{
  inputs,
  stable ? true,
  ...
}:

let
  # Whether the lib is stable variant
  inherit stable;

  # Decide which nixpkgs input to use
  nixpkgs = if stable then inputs.nixpkgs else inputs.nixpkgs-unstable;

  # Concat attributes
  concatAttrs = attrList: builtins.foldl' (x: y: x // y) { } attrList;

  # Extend lib with custom functions
  mkMyLib =
    { lib }:
    concatAttrs (
      builtins.map (x: import x (args // { inherit lib stable nixpkgs; })) [
        ./consts.nix
        ./image.nix
        ./io.nix
        ./reverse-proxy.nix
        ./secrets.nix
        ./utils.nix
      ]
    )
    // {
      inherit concatAttrs stable;
    };
in
nixpkgs.lib.extend (self: super: { codgician = mkMyLib { lib = self; }; })
