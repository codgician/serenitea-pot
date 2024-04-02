{ config, lib, pkgs, inputs, ... }: {
  imports = [
    (import "${inputs.mobile-nixos}/lib/configuration.nix" { device = "lenovo-krane"; })
  ];

  # Custom kernel
  mobile = {
    boot.stage-1 = {
      enable = true;
      kernel = {
        package = lib.mkForce (pkgs.callPackage ./kernel { });
        modular = true;
        modules = [
          "dm_mod"
          "dm_crypt"
          "tpm_tis_core"
          "tpm_tis_spi"
          "tpm_tis_i2c_cr50"
        ];
      };
      extraUtils = [
        { package = pkgs.clevis; }
        { package = pkgs.tpm2-tools; }
        { package = pkgs.cryptsetup; }
      ];
    };

    kernel.structuredConfig = [
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

    # Make panel landscape
    hardware.screen = lib.mkForce {
      width = 1920;
      height = 1200;
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/edf11839-2440-4e3f-9ae1-13edb4946341";
      fsType = "ext4";
    };
  };
  
  boot.initrd.luks.devices = {
    "LUKS-CHARLOTTE-ROOTFS" = {
      device = "/dev/disk/by-uuid/8fc43d94-f417-4607-85ac-3aa329916e8e";
    };
  };

  # TPM
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };
  environment.systemPackages = with pkgs; [
    clevis
    tpm2-tools
    cryptsetup
  ];

  nix.settings.max-jobs = lib.mkDefault 4;
}
