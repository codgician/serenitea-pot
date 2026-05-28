_:

# Extend `linuxKernel.packagesFor` so the CIX OOT kernel modules become
# attributes of every produced `linuxPackages.*` set. This mirrors the
# pattern in overlays/10-kernel-modules and ensures the modules rebuild
# automatically whenever the kernel changes.
#
# We use `lpself.callPackage` (a `newScope self` wrapper, see
# `pkgs/top-level/linux-kernels.nix:261`) rather than `final.callPackage`
# so that `kernel` and `kernelModuleMakeFlags` are resolved from the
# LATE-BOUND `self.kernel`. This matters because NixOS does
# `boot.kernelPackages.extend (self: super: { kernel = super.kernel.override {...kernelPatches...}; })`
# in `nixos/modules/system/boot/kernel.nix`; with `final.callPackage` we
# would capture the unpatched `super.kernel` at overlay-evaluation time
# and end up mixing kernel-dev paths from two different derivations.
#
# Each driver package file owns its own `fetchFromGitHub` (with the rev
# + hash pinned inline), so this overlay is purely a registration site.

_final: prev: {
  linuxKernel = prev.linuxKernel // {
    packagesFor =
      kernel:
      (prev.linuxKernel.packagesFor kernel).extend (
        lpself: _lpsuper: {
          cix-vpu-driver = lpself.callPackage ./cix-vpu-driver.nix { };
          cix-npu-driver = lpself.callPackage ./cix-npu-driver.nix { };
        }
      );
  };
}
