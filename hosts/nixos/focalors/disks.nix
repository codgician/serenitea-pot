{
  disks ? [
    "sda"
    "sdb"
    "sdc"
  ],
  ...
}:
{
  disko.devices.disk = {
    nixos = {
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
          nix = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/nix";
            };
          };
        };
      };
    };

    persist = {
      device = "/dev/${builtins.elemAt disks 1}";
      type = "disk";
      content = {
        type = "gpt";
        partitions.persist = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/persist";
          };
        };
      };
    };

    root = {
      device = "/dev/${builtins.elemAt disks 2}";
      type = "disk";
      content = {
        type = "gpt";
        partitions.root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
