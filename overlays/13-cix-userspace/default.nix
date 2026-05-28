_:

# Userspace CIX P1 packages, exposed under `pkgs.cix.*` so they sit
# alongside the kernel-coupled modules in `pkgs.linuxPackages.cix-*`
# without shadowing any upstream package (in particular, `pkgs.ffmpeg`
# stays unchanged — opt-in via `pkgs.cix.ffmpeg`).
#
# Each package file is self-contained: it owns its own `fetch*` call
# (with the rev + hash pinned inline), so this overlay is purely a
# registration site for the `pkgs.cix.*` namespace.

final: _prev: {
  cix = {
    vaapi = final.callPackage ./vaapi.nix {
      # The VA-API back-end needs `mvx-v4l2-controls.h`, which only
      # lives in the VPU driver source tree. Pull the (kernel-coupled)
      # driver for the *currently-selected* kernel so the header always
      # matches the running module.
      inherit (final.linuxPackages) cix-vpu-driver;
    };

    ffmpeg = final.callPackage ./ffmpeg.nix {
      inherit (final.linuxPackages) cix-vpu-driver;
    };

    firmware = final.callPackage ./firmware.nix { };
  };
}
