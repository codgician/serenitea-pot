{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [
    "uhci_hcd"
    "ehci_pci"
    "ahci"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.kernelParams = [ "console=ttyS0,115200" "iomem=relaxed" ];

  networking.useDHCP = lib.mkDefault true;

  # Enable QEMU guest agent
  services.qemuGuest.enable = true;

  # Enable OpenGL
  hardware.graphics.enable = true;

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  # CUDA support for nixpkgs
  nixpkgs.config.cudaSupport = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    gsp.enable = true;
    nvidiaPersistenced = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
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

  # Start ollama after limiting TDP
  systemd.services.ollama.after = [ "nvidia-power-limit.service" ];

  # Enable use of nvidia card in containers
  hardware.nvidia-container-toolkit.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
