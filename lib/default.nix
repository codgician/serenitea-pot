args@{
  inputs,
  ...
}:

let
  # Decide which nixpkgs input to use
  nixpkgs = inputs.nixpkgs;

  # Concat attributes
  concatAttrs = attrList: builtins.foldl' (x: y: x // y) { } attrList;

  # Extend lib with custom functions
  mkMyLib =
    { lib }:
    concatAttrs (
      builtins.map (x: import x (args // { inherit lib nixpkgs; })) [
        ./consts.nix
        ./image.nix
        ./io.nix
        ./reverse-proxy.nix
        ./secrets.nix
        ./service.nix
        ./utils.nix
      ]
    )
    // {
      inherit concatAttrs;
    };
in
nixpkgs.lib.extend (self: super: { codgician = mkMyLib { lib = self; }; })
