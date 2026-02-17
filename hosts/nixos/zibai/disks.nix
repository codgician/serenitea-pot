{
  disks ? [ "disk/by-id/ata-KIOXIA-EXCERIA_SATA_SSD_X1PB713BKLS4" ],
  ...
}:

{
  disko = {
    devices = {
      disk.main = {
        type = "disk";
        device = "/dev/${builtins.elemAt disks 0}";
        content = {
          type = "gpt";
          partitions = {
            esp = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "umask=0077"
                ];
              };
            };

            zroot = {
              size = "732G";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };

            l2arc = {
              size = "100%"; 
              # No content - raw partition for ZFS L2ARC cache
              # Add to dpool after installation:
              #   zpool add dpool cache /dev/disk/by-partlabel/disk-main-l2arc
            };
          };
        };
      };

      zpool.zroot = {
        type = "zpool";
        mountpoint = "/zroot";
        rootFsOptions = {
          atime = "off";
          compression = "zstd";
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          keylocation = "prompt";
          "com.sun:auto-snapshot" = "false";
        };

        options = {
          ashift = "12";
          autotrim = "on";
        };

        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
            options."com.sun:auto-snapshot" = "false";
          };

          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options."com.sun:auto-snapshot" = "false";
          };

          persist = {
            type = "zfs_fs";
            mountpoint = "/persist";
            options."com.sun:auto-snapshot" = "true";
          };
        };
      };
    };
  };
}
