{
  disks ? [
    "disk/by-id/nvme-KXG6AZNV512G_TOSHIBA_41GF71D3FDP3"
    "disk/by-id/nvme-PM9A1_NVMe_Samsung_1024GB_S65VNE0R502376"
  ],
  ...
}:
{
  disko.devices.disk = {
    main = {
      device = "/dev/${builtins.elemAt disks 0}";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1M";
            type = "EF02";
          };
          esp = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "luks";
              name = "crypted";
              extraFormatArgs = [
                "--cipher"
                "aes-xts-plain64"
              ];
              settings.allowDiscards = true;
              settings.crypttabExtraOpts = [
                "tpm2-device=auto"
                "tpm2-measure-pcr=yes"
              ];
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "root" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "discard=async"
                      "space_cache=v2"
                    ];
                  };
                  "nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "discard=async"
                      "space_cache=v2"
                    ];
                  };
                  "persist" = {
                    mountpoint = "/persist";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                      "discard=async"
                      "space_cache=v2"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };

    code = {
      device = "/dev/${builtins.elemAt disks 1}";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          code = {
            size = "100%";
            content = {
              type = "luks";
              name = "crypted-code";
              initrdUnlock = false;
              extraFormatArgs = [
                "--cipher"
                "aes-xts-plain64"
              ];
              settings = {
                allowDiscards = true;
                keyFile = "/persist/keys/crypted-code.key";
              };
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "code" = {
                    mountpoint = "/code";
                    mountOptions = [
                      "compress=zstd:1"
                      "noatime"
                      "discard=async"
                      "space_cache=v2"
                      "autodefrag"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
