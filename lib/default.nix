args@{ inputs, ... }:
let
  # `lib` of a nixpkgs branch with `lib.codgician` added; a host built from
  # another branch gets that branch's `lib`, which its NixOS modules expect.
  mkLib =
    nixpkgs:
    nixpkgs.lib.extend (
      lib: _: {
        codgician = lib.mergeAttrsList (
          map (file: import file (args // { inherit lib nixpkgs mkLib; })) [
            ./consts.nix
            ./image.nix
            ./io.nix
            ./nginx.nix
            ./service.nix
            ./utils.nix
          ]
        );
      }
    );
in
mkLib inputs.nixpkgs
