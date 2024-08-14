{ disks ? [ "nvme0n1" "nvme1n1" ], ... }:

let
  mkDiskConfig = disk: {
    type = "disk";
    device = "/dev/${disk}";
    content = {
      type = "gpt";
      partitions = {
        esp = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot-${disk}";
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
in
{
  disko = {
    extraRootModules = [ "zfs" ];
    devices = {
      # Disks: mirrored ZFS root
      disk = {
        nvme0n1 = mkDiskConfig (builtins.elemAt disks 0);
        nvme1n1 = mkDiskConfig (builtins.elemAt disks 1);
      };

      # zpool settings
      zpool.zroot = {
        type = "zpool";
        mode = "mirror";
        mountpoint = "/zroot";
        rootFsOptions = {
          compression = "on";
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
            mountpoint = "/nix/persist";
            options."com.sun:auto-snapshot" = "true";
          };

          openwrt-os = {
            type = "zfs_volume";
            size = "1G";
          };

          hass-os = {
            type = "zfs_volume";
            size = "64G";
          };
        };
      };
    };
  };
}
