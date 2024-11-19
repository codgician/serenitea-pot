# Always use prl-tools from unstable

{ inputs, ... }:

self: super:
let
  unstablePkgs = import inputs.nixpkgs-nixos-unstable {
    inherit (super) system;
    config.allowUnfree = true;
  };
in
{
  linuxPackages = super.linuxPackages.extend (lpself: lpsuper: {
    prl-tools = (unstablePkgs.linuxPackages.prl-tools.override {
      inherit (lpsuper) kernel;
    });
  });
}
