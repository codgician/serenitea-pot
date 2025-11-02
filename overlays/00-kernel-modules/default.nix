# Use version from unstable for specified kernel modules

{ inputs, lib, ... }:

self: super:
let
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (super) system;
    config.allowUnfree = true;
  };
in
{
  inherit (unstablePkgs) mstflint;
  linuxKernel = super.linuxKernel // {
    packagesFor =
      kernel:
      (super.linuxKernel.packagesFor kernel).extend (
        lpself: lpsuper:
        lib.genAttrs [
          "mstflint_access"
        ] (pkgName: unstablePkgs.linuxPackages.${pkgName}.override { inherit (lpsuper) kernel kernelModuleMakeFlags; })
      );
  };
}
