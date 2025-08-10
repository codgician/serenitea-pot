{ lib, ... }:
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
    kernelParams = [ "video=Virtual-1:3024x1890@120" ];
    extraModulePackages = [ ];
  };

  fileSystems."/persist".neededForBoot = true;

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "prl-tools" ];
  hardware.parallels.enable = true;

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
