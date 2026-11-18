{ config, lib, ... }:
let
  hasExtraPools = config.boot.zfs.extraPools != [ ];
in
{
  codgician = {
    services.rasdaemon.enable = true;

    system = {
      impermanence.wipeOnShutdown.zfs.enable = true;
      secure-boot.enable = true;

      # The TPM unlocks zroot. Generate the credential with
      # nix run .#mkzfscreds -- zroot > hosts/nixos/<host>/zroot.cred
      zfs-unlock.devices.zroot.credentialFile = ../nixos + "/${config.networking.hostName}/zroot.cred";
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Pools besides zroot are imported at boot and need their keys before mounting.
  boot.zfs.forceImportAll = hasExtraPools;
  systemd.services.zfs-mount.preStart = lib.mkIf hasExtraPools "${lib.getExe config.boot.zfs.package} load-key -a";

  security.tpm2 = {
    enable = lib.mkDefault true;
    abrmd.enable = true;
    pkcs11.enable = true;
  };

  hardware.enableRedistributableFirmware = true;
  hardware.graphics.enable = true;

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
