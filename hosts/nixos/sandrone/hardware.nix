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
      # The aarch64 default CMA reservation (32 MiB, set by
      # CMA_SIZE_MBYTES in common-config.nix) is exhausted before
      # `linlondp` can allocate fbdev framebuffers
      "cma=512M"
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

  # Silence the linlondp display engine's benign "err detect: ...
  # EMPTY|ACE0" flood. These are status-register snapshots the IRQ
  # handler reads during normal commit/flip activity, NOT real faults
  # (verified on hardware: AXIED=0, no TBU fault, fires at idle on a
  # 1080p output; a genuine underrun would set the separate URUN bit).
  # linlondp is a verbatim copy of mainline ARM `komeda`, which
  # classifies ACE0/IBSY as error-class and DRM_ERRORs them — a
  # known-noisy upstream behavior (cf. dri-devel 2022-07 "FLIP happened
  # but no pending commit"). `err_verbosity` is komeda's own debugfs
  # knob for exactly this; 0 disables event printing without touching
  # genuine probe/repair paths. A udev RUN re-applies it on every
  # linlondp bind because the value resets to the 0x0001 default on
  # driver re-probe (e.g. display reconfiguration) — a boot-time
  # oneshot would miss those. Verified the RUN reaches debugfs and
  # clears all five pipe instances.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="platform", DRIVER=="linlondp", RUN+="${pkgs.runtimeShell} -c 'for f in /sys/kernel/debug/linlondp*/err_verbosity; do [ -w \"$$f\" ] && echo 0 > \"$$f\"; done'"
  '';

  # Use `modesetting` as the primary X11 driver so Xorg/Xwayland picks up
  # whichever DRM device has a connected monitor (here: `linlondp` on the
  # CIX display engine, since the monitor is on the CIX-side DP outputs).
  # Keep `nvidia` so the discrete GPU remains available for compute
  # (CUDA, nvidia-uvm) without claiming the display.
  services.xserver.videoDrivers = [
    "modesetting"
    "nvidia"
  ];

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
    nvtopPackages.panthor
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
