# Only OS disks are managed by disko

{
  disks ? [
    "disk/by-id/nvme-SKHynix_HFS001TEM4X182N_5SDAN42221030AG17-part2"
    "disk/by-id/nvme-SKHynix_HFS001TEM4X182N_5SDAN42221030AG2H-part2"
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
            mountOptions = [
              "nofail"
              "umask=0077"
            ];
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
          atime = "off";
          compression = "off";
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

          lab = {
            type = "zfs_fs";
            mountpoint = "/zroot/lab";
            options = {
              direct = "always";
              "com.sun:auto-snapshot" = "false";
            };
          };
        };
      };
    };
  };
}
