{ disks ? [ "/dev/sda" ], ... }: {
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
      media9p = {
        device = "media9p";
        fsType = "9p";
        mountpoint = "/mnt/media";
        mountOptions = [
          "trans=virtio"
          "version=9p2000.L"
          "cache=loose"
        ];
      };
    };
    disk = {
      sda = {
        device = builtins.elemAt disks 0;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            esp = {
              start = "1M";
              end = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            nix = {
              end = "-0";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/nix";
              };
            };
          };
        };
      };
    };
  };
}
