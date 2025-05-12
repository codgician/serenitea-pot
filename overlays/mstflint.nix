# Always use mstflint and related kernel modules from unstable

{ inputs, ... }:

self: super:
let
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (super) system;
    config.allowUnfree = true;
  };
in
{
  inherit (unstablePkgs) mstflint;
  linuxPackages = super.linuxPackages.extend (
    lpself: lpsuper: {
      mstflint_access = unstablePkgs.linuxPackages.mstflint_access.override {
        inherit (lpsuper) kernel kmod;
        inherit (unstablePkgs) mstflint;
      };
    }
  );
}
