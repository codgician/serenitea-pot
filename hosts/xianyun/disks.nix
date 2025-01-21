{
  disks ? [ "vda" ],
  ...
}:
{
  disko.devices = {
    disk.vda = {
      imageSize = "12G";
      device = "/dev/${builtins.elemAt disks 0}";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1M";
            type = "EF02"; # for grub MBR
          };
          swap = {
            size = "2G";
            content = {
              type = "swap";
              discardPolicy = "both";
              resumeDevice = false;
            };
          };
          root = {
            size = "8G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
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
