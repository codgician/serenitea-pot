{ lib, pkgs, ... }:
let
  pipewireWithChromebookUcm = pkgs.pipewire.override {
    alsa-lib = pkgs.alsa-lib.override {
      alsa-ucm-conf = pkgs.alsa-ucm-conf-chromebook;
    };
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
        "xe"
      ];
    };

    kernelModules = [ "kvm-intel" ];
    # Force enable xe
    kernelParams = [
      "i915.force_probe=!46a8"
      "xe.force_probe=46a8"
    ];
    kernelPackages = pkgs.linuxPackages_testing;
    zfs.package = pkgs.zfs_unstable;
    supportedFilesystems = [ "vfat" ];
  };

  services = {
    dbus.packages = [ rustFp ];
    hardware.bolt.enable = true;
    thermald.enable = true;
    pipewire = {
      package = pipewireWithChromebookUcm;
      wireplumber = {
        package = pkgs.wireplumber.override {
          pipewire = pipewireWithChromebookUcm;
        };

        extraConfig."51-increase-headroom" = {
          "monitor.alsa.rules" = [
            {
              matches = [ { "node.name" = "~alsa_output.*"; } ];
              actions.update-props."api.alsa.headroom" = 2048;
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
    firmware = [ pkgs.redrix.max98390-firmware ];
    bluetooth.enable = true;
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
    sensor.iio.enable = true;
    graphics = {
      enable = true;
      extraPackages = with pkgs; [ intel-media-driver ];
    };
  };

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
