{
  disks ? [ "vda" ],
  ...
}:
{
  disko.devices = {
    disk.vda = {
      imageSize = "16G";
      device = "/dev/${builtins.elemAt disks 0}";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1M";
            type = "EF02"; # for grub MBR
          };
          root = {
            size = "12G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
          swap = {
            size = "2G";
            content = {
              type = "swap";
              discardPolicy = "both";
              resumeDevice = false;
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
  };
}
