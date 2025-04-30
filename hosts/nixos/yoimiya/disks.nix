# Only OS disks are managed by disko

{
  disks ? [
    "disk/by-id/nvme-WD_Blue_SN5000_1TB_251222801711"
    "disk/by-id/nvme-WD_Blue_SN5000_1TB_251222802843"
  ],
  ...
}:

let
  mkDiskConfig = id: {
    type = "disk";
    device = "/dev/${builtins.elemAt disks id}";
    content = {
      type = "gpt";
      partitions = {
        esp = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot-${builtins.toString id}";
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
    devices = {
      # Disks: mirrored ZFS root
      disk = {
        zroot-0 = mkDiskConfig 0;
        zroot-1 = mkDiskConfig 1;
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
        };
      };
    };
  };
}
