{ config, lib, pkgs, inputs, ... }: {
  imports = [
    (import "${inputs.mobile-nixos}/lib/configuration.nix" { device = "lenovo-krane"; })
  ];

  # Custom kernel
  mobile.boot.stage-1.kernel = {
    package = lib.mkForce (pkgs.callPackage ./kernel { });
    modules = [
      "dm_mod"
      "dm_crypt"
      "tpm_tis_core"
      "tpm_tis_spi"
      "tpm_tis_i2c_cr50"
    ];
  };

  mobile.kernel.structuredConfig = [
    (helpers: with helpers; {
      # dm_mod
      BLK_DEV_DM = module;
      CRYPTO_CRYPTD = module;
      CRYPTO_BLOWFISH = module;
      CRYPTO_TWOFISH = module;
      CRYPTO_SERPENT = module;
      CRYPTO_LRW = module;
      CRYPTO_USER_API_SKCIPHER = module;

      # Enable CR50 TPM support
      TCG_TIS_CORE = module;
      TCG_TIS_SPI = module;
      TCG_TIS_SPI_CR50 = yes;
      TCG_TIS_I2C_CR50 = module;
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
