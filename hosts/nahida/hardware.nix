{ config, lib, modulesPath, ... }: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.kernelParams = [ "console=ttyS0,115200" ];

  networking.useDHCP = lib.mkDefault true;

  # Enable QEMU guest agent
  services.qemuGuest.enable = true;

  # Enable OpenGL
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  # CUDA support for nixpkgs
  nixpkgs.config.cudaSupport = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = true;
    nvidiaSettings = true;
  };

  # Limit TDP for nvidia card
  systemd.services.nvidia-power-limit = {
    description = "Limit NVIDIA GPU Power Limit";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi -pl 300";
      Type = "oneshot";
    };
  };

  # Enable use of nvidia card in containers
  hardware.nvidia-container-toolkit.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
