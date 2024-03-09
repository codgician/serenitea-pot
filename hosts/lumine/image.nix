{ pkgs, modulesPath, lib, config, ... }: {
  imports = [
    (modulesPath + "/virtualisation/azure-image.nix")
  ];

  # Configure disk size
  virtualisation.azureImage.diskSize = 8 * 1024;

  # Override implementation in azure-image.nix to create efi partition table
  system.build.azureImage = lib.mkForce
    (import "${modulesPath}/../lib/make-disk-image.nix" {
      inherit pkgs lib config;
      partitionTableType = "efi";
      postVM = ''
        ${pkgs.vmTools.qemu}/bin/qemu-img convert -f raw -o subformat=fixed,force_size -O vpc $diskImage $out/nixos.vhd
        rm $diskImage
      '';
      diskSize = config.virtualisation.azureImage.diskSize;
      format = "raw";
    });
}
