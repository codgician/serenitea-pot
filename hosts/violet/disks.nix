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
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "esp";
              start = "1MiB";
              end = "512MiB";
              bootable = true;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            }
            {
              name = "nix";
              start = "512MiB";
              end = "100%";
              part-type = "primary";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/nix";
              };
            }
          ];
        };
      };
    };
  };
}
