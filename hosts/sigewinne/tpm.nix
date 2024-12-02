{ pkgs, ... }:
let
  luksName = "LUKS-SIGEWINNE-ROOTFS";
  luksDev = "/dev/mmcblk0p6";
in
{
  mobile.boot.stage-1 = {
    kernel = {
      modular = true;
      modules = [
        "dm_mod"
        "dm_crypt"
        "tpm_tis_core"
        "tpm_tis_spi"
        "tpm_tis_i2c_cr50"
      ];
    };

    tasks = [
      (pkgs.writeText "unlock-root-partition-task.rb" ''
        class Tasks::UnlockRootPartition < SingletonTask
          def initialize()
            add_dependency(:Task, Tasks::UDev.instance)
            add_dependency(:Devices, "${luksDev}")
            add_dependency(:Mount, "/run")
            add_dependency(:Target, :Environment)
            add_dependency(:Task, Tasks::Splash.instance)
          end
          
          def run()
            begin
              Progress.exec_with_message("Unlocking rootfs with clevis...") do
                System.run("/bin/unlock-rootfs")
              end
            rescue System::CommandError
              Tasks::Luks.new("${luksDev}", "${luksName}", {})
            end
          end
        end
      '')
    ];

    # Symlink dependencies to /bin
    contents = [
      {
        object = "${pkgs.bash}/bin/bash";
        symlink = "/bin/bash";
      }
      {
        object = "${pkgs.coreutils}/bin/cat";
        symlink = "/bin/cat";
      }
      {
        object = pkgs.writeShellApplication {
          name = "unlock-rootfs";
          runtimeInputs = with pkgs; [ clevis cryptsetup tpm2-tools ];
          text = "clevis luks unlock -d /dev/mmcblk0p6 -n ${luksName} >> /clevis-unlock.log 2>&1";
        };
        symlink = "/bin/unlock-rootfs";
      }
    ];

    # Add clevis as extra utilities
    extraUtils = [
      { package = pkgs.clevis; }
      { package = pkgs.cryptsetup; }
      { package = pkgs.tpm2-tools; }
      {
        package = pkgs.runCommand "empty" { } "mkdir -p $out";
        extraCommand = ''
          copy_bin_and_libs ${pkgs.jose}/bin/jose
          copy_bin_and_libs ${pkgs.curl}/bin/curl
          copy_bin_and_libs ${pkgs.bash}/bin/bash

          copy_bin_and_libs ${pkgs.tpm2-tools}/bin/.tpm2-wrapped
          mv $out/bin/{.tpm2-wrapped,tpm2}
          cp {${pkgs.tpm2-tss},$out}/lib/libtss2-tcti-device.so.0

          copy_bin_and_libs ${pkgs.clevis}/bin/.clevis-wrapped
          mv $out/bin/{.clevis-wrapped,clevis}

          for BIN in ${pkgs.clevis}/bin/clevis-decrypt*; do
            copy_bin_and_libs $BIN
          done

          for BIN in $out/bin/clevis{,-decrypt{,-null,-tang,-tpm2}}; do
            sed -i $BIN -e 's,${pkgs.bash},,' -e 's,${pkgs.coreutils},,'
          done

          for BIN in ${pkgs.clevis}/bin/clevis-luks*; do
            copy_bin_and_libs $BIN
          done

          for BIN in $out/bin/clevis-luks*; do
            sed -i $BIN -e 's,${pkgs.bash},,' -e 's,${pkgs.coreutils},,'
          done

          sed -i $out/bin/clevis-decrypt-tpm2 -e 's,tpm2_,tpm2 ,'
        '';
      }
    ];
  };

  # Build TPM kernel modules
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

  boot.initrd.luks.forceLuksSupportInInitrd = true;
}
