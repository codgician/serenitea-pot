{ lib, pkgs, ... }:
let
  chromeosUcm = pkgs.redrix.chromeos-ucm.override { noiseReduction = true; };
  pipewireWithChromeosUcm = pkgs.pipewire.override {
    alsa-lib = pkgs.alsa-lib.override { alsa-ucm-conf = chromeosUcm; };
  };
  rustFp = pkgs.nur.repos.codgician.rust-fp;
in

{
  # HP Elite Dragonfly Chromebook with an Alder Lake-U i7-1265U.
  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "nvme"
        "thunderbolt"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
      kernelModules = [
        "intel_lpss_pci"
        "tpm_tis_i2c_cr50"
      ];
    };

    kernelModules = [ "kvm-intel" ];
    kernelParams = [
      "iommu.passthrough=0"
      "intel_iommu=on"
      "i915.enable_guc=3"
      "snd_sof.ipc_type=0"
      "snd_sof.fw_path=intel/sof/redrix"
      "snd_sof.fw_filename=sof-adl.ri"
      "snd_sof.tplg_path=intel/sof-tplg/redrix"
      "snd_sof.tplg_filename=sof-adl-max98390-rt5682.tplg"
    ];
    kernelPackages = pkgs.linuxPackages_testing;
    kernelPatches = [
      {
        name = "cros-ec-typec-priority-mode-selection";
        patch = pkgs.fetchpatch {
          url = "https://lore-kernel.gnuweeb.org/lkml/20260129131928.794768-1-akuchynski@chromium.org/raw";
          hash = "sha256-LO2jdGHfeDN+9ys7IE7DTV8DBHdizqxLhDXXMd0Nv0k=";
        };
      }
      {
        name = "cros-ec-typec-altmode-priority";
        patch = pkgs.fetchpatch {
          url = "https://lore-kernel.gnuweeb.org/lkml/20260129131928.794768-2-akuchynski@chromium.org/raw";
          hash = "sha256-rPJSuit8gm8LU1FTCf7NXYCKYaID8XfFRm7QH/XHEts=";
        };
      }
      {
        name = "cros-ec-typec-notifier-first";
        patch = ./kernel/cros-ec-typec-notifier-first.patch;
      }
      {
        name = "cros-ec-typec-usb4-capability";
        patch = ./kernel/cros-ec-typec-usb4-capability.patch;
      }
      {
        name = "cros-ec-typec-usb4-mode-entry";
        patch = ./kernel/cros-ec-typec-usb4-mode-entry.patch;
      }
    ];
    zfs.package = pkgs.zfs_unstable;
    supportedFilesystems = [ "vfat" ];
  };

  services = {
    dbus.packages = [ rustFp ];
    keyd = {
      enable = true;
      keyboards.redrix = {
        ids = [ "0001:0001:a51dd4d3" ];
        settings.main = {
          "leftalt+leftmeta" = "capslock";
        };
        settings.meta = {
          back = "f1";
          refresh = "f2";
          zoom = "f3";
          scale = "f4";
          sysrq = "f5";
          brightnessdown = "f6";
          brightnessup = "f7";
          kbdillumtoggle = "f8";
          playpause = "f9";
          micmute = "f10";
          mute = "f11";
          volumedown = "f12";
          volumeup = "f13";
        };
      };
    };
    hardware.bolt.enable = true;
    thermald = {
      enable = true;
      configFile = ./thermald.xml;
    };
    pipewire = {
      package = pipewireWithChromeosUcm;

      # Electron/Chromium clients (Cider, Edge, Teams) ask for ~10 ms buffers,
      # which drags the whole graph, EasyEffects included, down to a 480/512
      # sample quantum. On the powersave governor that is where the xruns show
      # up; keep the graph at the 1024-sample (21 ms) default instead.
      extraConfig.pipewire."92-min-quantum"."context.properties"."default.clock.min-quantum" = 1024;

      wireplumber = {
        package = pkgs.wireplumber.override {
          pipewire = pipewireWithChromeosUcm;
        };

        extraConfig."51-increase-headroom" = {
          "monitor.alsa.rules" = [
            {
              matches = [ { "node.name" = "~alsa_output.*"; } ];
              actions.update-props."api.alsa.headroom" = 2048;
            }
          ];
        };

        # WirePlumber closes an idle PCM after 5 s; the SOF DSP then hits PCI
        # runtime suspend 2 s later and every new stream pays a firmware
        # resume, which is the source of the gaps/pops at playback start on
        # this card. Keep the built-in outputs open instead.
        extraConfig."51-sof-no-suspend" = {
          "monitor.alsa.rules" = [
            {
              matches = [ { "node.name" = "~alsa_output.pci-0000_00_1f.3.*"; } ];
              actions.update-props."session.suspend-timeout-seconds" = 0;
            }
          ];
        };

        # The generated Pro Audio profile probes every SOF PCM, including the
        # ChromeOS-only Bluetooth offload and 16 kHz DMIC endpoints. Use the UCM
        # HiFi profile exclusively and avoid repeated -EINVAL kernel messages.
        extraConfig."51-disable-pro-audio" = {
          "monitor.alsa.rules" = [
            {
              matches = [ { "device.name" = "~alsa_card.*"; } ];
              actions.update-props."api.acp.disable-pro-audio" = true;
            }
          ];
        };

        # Publish the libcamera camera on demand and hide the 32 raw IPU6 capture
        # nodes from applications.
        extraConfig."camera" = {
          "wireplumber.profiles".main = {
            "monitor.v4l2" = "disabled";
            "monitor.libcamera" = "optional";
          };
        };
      };
    };
  };

  # ChromeOS's Redrix UCM writes Digital Volume 153/155, then runs
  # sound_card_init boot_time_calibration (redrix.MAX98390.yaml). That
  # calibration needs the factory VPD keys dsm_calib_r0_{0..3} and
  # dsm_calib_temp_{0..3}, which this unit's RO VPD does not contain
  # (coreboot log: "failed to find key in VPD: dsm_calib_r0_0"). Its failure
  # path enables safe mode: safe_mode_volume = 138 (-11 dB) on all four
  # amplifiers. The user reports matching loudness at 138; the comparison
  # device's calibration state has not been read. The native UCM's HiFi
  # verb sets 138 directly (overlays/24-redrix-firmware/ucm/linux-adaptation.patch), so
  # selecting HiFi alone applies both the boot sequence and the safe-mode gain.
  systemd.services.redrix-audio-boot = {
    description = "Apply Redrix Chromebook audio settings";
    wantedBy = [ "sound.target" ];
    after = [ "sound.target" ];
    unitConfig.ConditionPathExists = "/dev/snd/controlC0";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    environment.ALSA_CONFIG_UCM2 = "${chromeosUcm}/share/alsa/ucm2";
    script = ''
      exec ${pkgs.alsa-utils}/bin/alsaucm -c hw:sofrt5682 set _verb HiFi
    '';
  };

  environment.systemPackages = with pkgs; [
    lm_sensors
    smartmontools
    pciutils
    nvme-cli
    usbutils
    powertop
    nvtopPackages.intel
    fw-ectool
    rustFp
  ];

  security = {
    pam.services.kde-fingerprint.text = ''
      auth    sufficient    ${rustFp}/lib/librust_fp_pam_module.so
      account sufficient    ${rustFp}/lib/librust_fp_pam_module.so
    '';

    tpm2 = {
      enable = true;
      pkcs11.enable = true;
    };
  };

  hardware = {
    firmware = [
      pkgs.redrix.max98390-firmware
      pkgs.redrix.sof-firmware
    ];
    bluetooth.enable = true;
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
    sensor.iio.enable = true;
    graphics = {
      enable = true;
      extraPackages = with pkgs; [ intel-media-driver ];
    };
  };

  # keyd remaps only the built-in keyboard here. Preserve its internal status
  # so libinput suppresses the remapped keys in tablet mode as well.
  environment.etc."libinput/local-overrides.quirks".text = ''
    [Odette keyd internal keyboard]
    MatchUdevType=keyboard
    MatchName=keyd virtual keyboard
    MatchVendor=0x0FAC
    MatchProduct=0x0ADE
    AttrKeyboardIntegration=internal
  '';

  powerManagement.cpuFreqGovernor = "powersave";

  systemd.services.rust-fp-dbus-interface = {
    description = "Provide fingerprint enrollment and matching over D-Bus";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "exec";
      ExecStart = "${rustFp}/bin/rust-fp-dbus-interface";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };

  # The Redrix EC otherwise aborts S0ix entry after its firmware timeout.
  systemd.services.cros-ec-timeout = {
    description = "Disable ChromeOS EC suspend timeout";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    requires = [ "systemd-modules-load.service" ];
    unitConfig.ConditionPathExists = "/sys/kernel/debug/cros_ec/suspend_timeout_ms";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      echo 65535 > /sys/kernel/debug/cros_ec/suspend_timeout_ms
    '';
  };

  fileSystems."/persist".neededForBoot = true;

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
