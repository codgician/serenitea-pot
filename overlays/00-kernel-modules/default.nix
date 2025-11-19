# Use version from unstable for specified kernel modules

{ inputs, lib, ... }:

final: prev:
let
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (prev) system;
    config.allowUnfree = true;
  };
in
{
  inherit (unstablePkgs) mstflint;
  linuxKernel = prev.linuxKernel // {
    packagesFor =
      kernel:
      (prev.linuxKernel.packagesFor kernel).extend (
        lpself: lpsuper:
        lib.genAttrs
          [
            "mstflint_access"
          ]
          (
            pkgName:
            unstablePkgs.linuxPackages.${pkgName}.override { inherit (lpsuper) kernel kernelModuleMakeFlags; }
          )
      );
  };
}
