# Only OS disks are managed by disko

let
  mkDiskConfig = id: device: {
    type = "disk";
    inherit device;
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
        zroot-0 = mkDiskConfig 0 "/dev/disk/by-id/nvme-SKHynix_HFS001TEM4X182N_5SDAN42221030AG17-part2";
        zroot-1 = mkDiskConfig 1 "/dev/disk/by-id/nvme-SKHynix_HFS001TEM4X182N_5SDAN42221030AG2H-part2";
      };

      # zpool settings
      zpool.zroot = {
        type = "zpool";
        mode = "mirror";
        mountpoint = "/zroot";
        rootFsOptions = {
          acltype = "posixacl";
          atime = "off";
          "com.sun:auto-snapshot" = "false";
          compression = "off";
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          keylocation = "prompt";
          xattr = "sa";
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
