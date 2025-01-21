{
  disks ? [ "vda" ],
  ...
}:
{
  disko = {
    devices = {
      disk.sda = {
        imageSize = "8G";
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
              end = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            zroot = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };

      # zpool
      zpool.zroot = {
        type = "zpool";
        mountpoint = "/zroot";
        rootFsOptions = {
          atime = "off";
          compression = "on";
          "com.sun:auto-snapshot" = "false";
        };

        options = {
          ashift = "12";
          autotrim = "on";
          autoexpand = "on";
        };

        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
          };

          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options."com.sun:auto-snapshot" = "false";
          };

          persist = {
            type = "zfs_fs";
            mountpoint = "/nix/persist";
          };
        };
      };
    };
  };
}
