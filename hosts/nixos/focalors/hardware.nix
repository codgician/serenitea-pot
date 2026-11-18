{ lib, pkgs, ... }:
let
  prlKdeDynamicResolution = pkgs.writeShellApplication {
    name = "prl-kde-dynamic-resolution";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      udevadm monitor --udev --subsystem-match=drm |
        while IFS= read -r event; do
          # virtio-gpu emits the resize on the DRM card, not its connector.
          [[ "$event" == *" change "*"/drm/card"*" (drm)" ]] || continue

          echo "DRM change received; rearming prlcc"
          systemctl --user restart prlcc.service

          # Drop events caused by prlcc synchronizing the current window size.
          sleep 1
          while IFS= read -r -t 0.01 _pending_event; do :; done
        done
    '';
  };
in
{
  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "sr_mod"
      ];
    };

    supportedFilesystems = [
      "vfat"
      "zfs"
    ];
    kernelParams = [ "video=Virtual-1:3024x1890@120" ];
  };

  hardware.parallels.enable = true;

  # prlcc dynamically loads GTK/GDK to inspect the Wayland screen, but the
  # nixpkgs wrapper does not expose them. On Plasma, prlcc receives subsequent
  # resize events but fails to apply them through its GNOME-specific Wayland
  # path. Rearm it after each DRM mode change so the next resize is accepted.
  systemd.user.services = {
    prlcc = {
      wants = [ "prl-kde-dynamic-resolution.service" ];
      after = [ "prl-kde-dynamic-resolution.service" ];
      environment.LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.gtk3 ];
      # prlcp crashes while cleaning up Wayland objects if systemd sends
      # SIGTERM to all prlcc helpers concurrently. Let prlcc exit cleanly,
      # then have systemd kill any remaining helpers without running cleanup.
      serviceConfig.KillMode = "mixed";
    };

    prl-kde-dynamic-resolution = {
      description = "Parallels dynamic resolution for KDE Plasma";
      wantedBy = [ "graphical-session.target" ];
      after = [ "plasma-kwin_wayland.service" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = lib.getExe prlKdeDynamicResolution;
        Restart = "on-failure";
        RestartSec = 1;
      };
    };
  };

  # Disable until Parallels' Linux vTPM passes systemd's TPM2_TestParms AES-128-CFB capability check.
  systemd.tpm2.enable = false;

  nix.settings = {
    extra-platforms = [ "x86_64-linux" ];
    extra-sandbox-paths = [
      "/run/binfmt"
    ];
  };
}
