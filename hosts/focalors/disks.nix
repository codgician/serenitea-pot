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
    };
    disk = {
      sda = {
        device = builtins.elemAt disks 0;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            esp = {
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
                format = "bcachefs";
                mountpoint = "/nix";
              };
            };
          };
        };
      };
    };
  };
}
