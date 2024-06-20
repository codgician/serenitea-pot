# This module is based on:
# https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/azure-image.nix

{ pkgs, modulesPath, lib, config, ... }:
let
  cfg = config.codgician.image.azure;
  types = lib.types;
in
{
  options.codgician.image.azure = {
    enable = lib.mkEnableOption ''
      Create Azure vhd image at `system.build.azureImage`.
    '';

    diskSize = lib.mkOption {
      type = with types; either (enum [ "auto" ]) int;
      default = "auto";
      description = lib.mdDoc ''
        Disk image size (MB).
      '';
    };

    bootSize = lib.mkOption {
      type = types.int;
      default = 512;
      description = ''
        EFI partition size (MB).
      '';
    };

    contents = lib.mkOption {
      type = with types; listOf attrs;
      default = [ ];
      description = ''
        Extra contents to add to the image.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Override implementation in azure-image.nix to create efi partition table
    system.build.azureImage = lib.mkForce
      (import "${modulesPath}/../lib/make-disk-image.nix" {
        inherit pkgs lib;
        inherit (cfg) diskSize contents;
        bootSize = "${builtins.toString cfg.bootSize}M";

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
        format = "raw";
      });
  };
}
