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
      kernelModules = [ ];
    };

    supportedFilesystems = [
      "vfat"
      "zfs"
    ];
    kernelModules = [ ];
    kernelPackages = pkgs.linuxPackages_6_18;
    zfs.package = pkgs.zfs_2_4;
    kernelParams = [ "video=Virtual-1:3024x1890@120" ];
    extraModulePackages = [ ];
  };

  fileSystems."/persist".neededForBoot = true;

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

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

  # TPM
  systemd.tpm2.enable = true;
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
  };

  nix.settings = {
    extra-platforms = [ "x86_64-linux" ];
    extra-sandbox-paths = [
      "/run/binfmt"
      # "/media/psf/RosettaLinux"
    ];
  };

  # prlbinfmtconfig.sh would only register binfmt when systemd-binfmt.service is enabled.
  # Following lines are added to ensure the service exists and is enabled when prlstoolsd.service runs
  # boot.binfmt.registrations.RosettaLinux = {
  #   interpreter = "/media/psf/RosettaLinux/rosetta";

  #   # The required flags for binfmt are documented by Apple:
  #   # https://developer.apple.com/documentation/virtualization/running_intel_binaries_in_linux_vms_with_rosetta
  #   magicOrExtension = ''\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00'';
  #   mask = ''\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'';
  #   fixBinary = true;
  #   matchCredentials = true;
  #   preserveArgvZero = false;

  #   # Remove the shell wrapper and call the runtime directly
  #   wrapInterpreterInShell = false;
  # };
}
