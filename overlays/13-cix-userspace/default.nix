_:

# Userspace CIX P1 packages, exposed under `pkgs.cix.*` so they sit
# alongside the kernel-coupled modules in `pkgs.linuxPackages.cix-*`
# without shadowing any upstream package (in particular, `pkgs.ffmpeg`
# stays unchanged — opt-in via `pkgs.cix.ffmpeg`).
#
# Each package file owns its source pin; this overlay only registers the
# `pkgs.cix.*` namespace and wires dependencies shared between packages.

final: _prev:
let
  libva = final.callPackage ./libva.nix { };
  media-engine = final.callPackage ./media-engine.nix { };
in
{
  cix = {
    inherit libva media-engine;
    vaapi = final.callPackage ./vaapi.nix {
      inherit (final.linuxPackages) cix-vpu-driver;
      cix-media-engine = media-engine;
      cix-libva = libva;
    };

    ffmpeg = final.callPackage ./ffmpeg.nix {
      inherit (final.linuxPackages) cix-vpu-driver;
    };

    firmware = final.callPackage ./firmware.nix { };
  };
}
