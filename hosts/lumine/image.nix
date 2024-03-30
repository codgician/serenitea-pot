{ pkgs, modulesPath, lib, config, ... }: {
  imports = [
    (modulesPath + "/virtualisation/azure-image.nix")
  ];

  # Configure disk size
  virtualisation.azureImage.diskSize = 32 * 1024;

  # Override implementation in azure-image.nix to create efi partition table
  system.build.azureImage = lib.mkForce
    (import "${modulesPath}/../lib/make-disk-image.nix" {
      inherit pkgs lib;

      config = config // {
        # For disk images, allow elevating without password.
        # This is because host ssh key is not packaged into disk image for security,
        # so agenix decryption will not work out of the box, causing users having no valid password.
        # SSH with certificate will be the only way to authenticate at first boot.
        security.sudo.wheelNeedsPassword = lib.mkForce false;
      };

      partitionTableType = "efi";
      postVM = ''
        ${pkgs.vmTools.qemu}/bin/qemu-img convert -f raw -o subformat=fixed,force_size -O vpc $diskImage $out/nixos.vhd
        rm $diskImage
      '';
      diskSize = config.virtualisation.azureImage.diskSize;
      format = "raw";
    });
}
