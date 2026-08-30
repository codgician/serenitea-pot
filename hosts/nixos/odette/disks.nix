{
  disks ? [ "nvme0n1" ],
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
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          swap = {
            size = "40G";
            content = {
              type = "luks";
              name = "cryptswap";
              extraFormatArgs = [
                "--cipher"
                "aes-xts-plain64"
              ];
              settings = {
                allowDiscards = true;
                crypttabExtraOpts = [
                  "tpm2-device=auto"
                  "tpm2-measure-pcr=yes"
                ];
              };
              content = {
                type = "swap";
                discardPolicy = "both";
                resumeDevice = true;
              };
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
              settings = {
                allowDiscards = true;
                crypttabExtraOpts = [
                  "tpm2-device=auto"
                  "tpm2-measure-pcr=yes"
                ];
              };
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
  };
}
