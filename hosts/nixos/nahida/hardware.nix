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
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.kernelParams = [
    "console=ttyS0,115200"
    "iomem=relaxed"
  ];

  networking.useDHCP = lib.mkDefault true;

  # Selfhost mlnx-ofed-nixos
  hardware.mlnx-ofed = {
    enable = true;
    fwctl.enable = true;
    kernel-mft.enable = true;
  };

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
  systemd.services.nvidia-gpu-config = {
    description = "Configure NVIDIA GPU";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = [
        "${pkgs.coreutils}/bin/echo 'Limiting NVIDIA GPU TDP to 350W...'"
        "${config.hardware.nvidia.package.bin}/bin/nvidia-smi -pl 350"
        # "${pkgs.coreutils}/bin/echo 'Disabling RGB effects...'"
        # "${lib.getExe pkgs.openrgb} --mode static --color 000000"
      ];
      Type = "oneshot";
    };
  };

  # Start ollama after configuring GPU
  systemd.services.ollama.after = [ "nvidia-gpu-config.service" ];

  # Enable use of nvidia card in containers
  hardware.nvidia-container-toolkit.enable = true;

  # Disable RGB for graphic
  # services.hardware.openrgb = {
  #   enable = true;
  #   motherboard = "amd";
  # };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
