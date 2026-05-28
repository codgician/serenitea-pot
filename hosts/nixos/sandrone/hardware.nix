{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  boot = {
    initrd = {
      availableKernelModules = [ ];
      kernelModules = [ ];
    };

    supportedFilesystems = [ "vfat" ];
    kernelModules = [
      "amvx" # CIX P1 VPU (Linlon v5276) — V4L2 M2M video accelerator.
      "aipu" # CIX P1 Zhouyi v3 NPU.
    ];
    kernelParams = [
      "iommu.passthrough=1"
      # CIX P1 firmware leaves clocks lacking explicit Linux owners; without
      # this the common clock framework gates them off during bring-up.
      "clk_ignore_unused"
    ];
    kernelPackages = pkgs.linuxPackages_6_18;
    kernelPatches = import ./kernel.nix { inherit inputs lib; };
    zfs.package = pkgs.zfs_2_4;
    extraModulePackages = with config.boot.kernelPackages; [
      cix-vpu-driver
      cix-npu-driver
    ];
  };

  hardware.firmware = [ pkgs.cix.firmware ];

  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    # Register the CIX VA-API back-end (`libcix_va_drv_video.so`) under
    # `/run/opengl-driver/lib/dri/`, the standard libva search path.
    # Apps then load it by name via `LIBVA_DRIVER_NAME=cix` (set
    # globally below).
    extraPackages = [ pkgs.cix.vaapi ];
  };

  # Make CIX the default VA-API driver for every libva client (mpv,
  # browsers, ffmpeg's vaapi backend, etc.). Apps that want a different
  # backend can still override per-invocation.
  environment.sessionVariables.LIBVA_DRIVER_NAME = "cix";

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    gsp.enable = true;
    nvidiaPersistenced = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # Global packages
  environment.systemPackages = with pkgs; [
    lm_sensors
    smartmontools
    pciutils
    nvme-cli
    usbutils
    powertop
    nvtopPackages.nvidia
    # CIX-patched ffmpeg as the system `ffmpeg`. Adds V4L2 M2M
    # decode/encode for the CIX P1 VPU on top of upstream 5.1.7;
    # nothing removed, so every existing `ffmpeg` invocation keeps
    # working and gains hardware acceleration when paired with
    # `-hwaccel vaapi` (with `LIBVA_DRIVER_NAME=cix` set above).
    cix.ffmpeg
    # `vainfo` confirms which VA-API driver libva picks up; `v4l2-ctl`
    # enumerates and probes the VPU's V4L2 M2M `/dev/video*` nodes.
    libva-utils
    v4l-utils
  ];

  # tpm2# TPM
  security.tpm2 = {
    enable = true;
    #abrmd.enable = true;
    pkcs11.enable = true;
  };

  hardware.enableRedistributableFirmware = true;

  fileSystems."/persist".neededForBoot = true;

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
