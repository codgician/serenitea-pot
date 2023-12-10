# Two NVME SSD forming RAID1 as boot drive.

{ lib, disks ? [ "/dev/nvme0n1" "/dev/nvme1n1" ], ... }: {
  disko.devices = {
    nodev = {
      root = {
        fsType = "tmpfs";
        mountpoint = "/";
        mountOptions = [
          "size=4G"
          "mode=755"
        ];
      };
    };

    disk = lib.genAttrs disks (device: {
      type = "disk";
      inherit device;
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1M";
            type = "EF02"; # for grub MBR
          };
          esp = {
            size = "512M";
            type = "EF00";
            content = {
              type = "mdraid";
              name = "boot";
            };
          };
          mdadm = {
            size = "100%";
            content = {
              type = "mdraid";
              name = "raid1";
            };
          };
        };
      };
    });

    mdadm = {
      boot = {
        type = "mdadm";
        level = 1;
        metadata = "1.0";
        content = {
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot";
        };
      };
      raid1 = {
        type = "mdadm";
        level = 1;
        content = {
          type = "luks";
          name = "crypted";
          settings.keyFile = "/tmp/secret.key";
          settings.allowDiscards = true;
          content = {
            type = "filesystem";
            format = "xfs";
            mountpoint = "/nix";
          };
        };
      };
    };
  };
}
