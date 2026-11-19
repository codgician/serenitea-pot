args@{ inputs, ... }:
let
  inherit (inputs) nixpkgs;
in
nixpkgs.lib.extend (
  lib: _: {
    codgician = lib.mergeAttrsList (
      map (file: import file (args // { inherit lib nixpkgs; })) [
        ./consts.nix
        ./image.nix
        ./io.nix
        ./nginx.nix
        ./service.nix
        ./utils.nix
      ]
    );
  }
)
