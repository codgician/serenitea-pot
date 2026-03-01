{
  disks ? [ "vda" ],
  ...
}:
{
  disko = {
    devices = {
      disk.vda = {
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
          acltype = "posixacl";
          atime = "off";
          "com.sun:auto-snapshot" = "false";
          compression = "on";
          xattr = "sa";
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
            postCreateHook = "zfs snapshot zroot/root@empty";
          };

          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options."com.sun:auto-snapshot" = "false";
          };

          persist = {
            type = "zfs_fs";
            mountpoint = "/persist";
          };
        };
      };
    };
  };
}
