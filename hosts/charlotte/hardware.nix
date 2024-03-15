{ config, lib, pkgs, inputs, ... }: {
  imports = [
    (import "${inputs.mobile-nixos}/lib/configuration.nix" { device = "lenovo-krane"; })
  ];

  # Custom kernel
  mobile.boot.stage-1.kernel = {
    package = lib.mkForce (pkgs.callPackage ./kernel { });
    additionalModules = [
      "tpm_tis_core"
      "tpm_tis_spi"
      "tcg_tis_i2c_cr50"
    ];
  };
  
  mobile.kernel.structuredConfig = [
    (helpers: with helpers; {
      # Enable CR50 TPM support
      TCG_TIS_CORE        = module;
      TCG_TIS_SPI         = module;
      TCG_TIS_SPI_CR50    = yes;
      TCG_TIS_I2C_CR50    = module;
    })
  ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/b2dccf20-c978-4335-8591-729cfc8d7da3";
      fsType = "ext4";
    };
  };

  boot.initrd.luks.devices = {
    "LUKS-CHARLOTTE-ROOTFS" = {
      device = "/dev/disk/by-uuid/ee50e9c7-b47d-4202-bed2-d7b275b40e40";
    };
  };

  # Make panel landscape
  mobile.hardware.screen = lib.mkForce {
    width = 1920;
    height = 1200;
  };

  nix.settings.max-jobs = lib.mkDefault 4;
}
