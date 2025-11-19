# Use version from unstable for specified kernel modules

{ lib, ... }:

final: prev: {
  inherit (prev.unstable) mstflint;
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
            prev.unstable.linuxPackages.${pkgName}.override { inherit (lpsuper) kernel kernelModuleMakeFlags; }
          )
      );
  };
}
