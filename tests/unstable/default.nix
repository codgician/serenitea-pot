# A manifest with `stable = false` builds its host from the unstable inputs.
# These small hosts, one per class, are evaluated without building anything.
{ lib, pkgs, ... }:
let
  # Only the PCR bank at offset 72 is read at evaluation time.
  credentialFile = builtins.toFile "zroot.cred" (lib.strings.replicate 18 "AAAA" + "AAAL");

  nixosHost = lib.codgician.mkNixosSystem {
    hostName = "unstable";
    inherit (pkgs.stdenv.hostPlatform) system;
    stable = false;
    modules = [
      {
        networking.hostId = "deadbeef";
        users.allowNoPasswordLogin = true;
        boot.loader.systemd-boot.enable = true;
        fileSystems = {
          "/" = {
            device = "zroot/root";
            fsType = "zfs";
          };
          "/boot" = {
            device = "/dev/disk/by-partlabel/disk-main-esp";
            fsType = "vfat";
          };
        };
        codgician.system.zfs-unlock = {
          enable = true;
          devices.zroot = { inherit credentialFile; };
        };
        system.stateVersion = "26.05";
      }
    ];
  };

  darwinHost = lib.codgician.mkDarwinSystem {
    hostName = "unstable";
    system = "aarch64-darwin";
    stable = false;
    modules = [
      {
        codgician.secrets.hosts = [ "furina" ];
        codgician.users.codgi.enable = true;
        system.primaryUser = "codgi";
        home-manager.users.codgi.home.stateVersion = "26.05";
        system.stateVersion = 7;
      }
    ];
  };

  evaluates =
    name: host:
    pkgs.writeText name (builtins.unsafeDiscardStringContext host.config.system.build.toplevel.drvPath);
in
{
  unstableNixos = evaluates "unstable-nixos" nixosHost;
  unstableDarwin = evaluates "unstable-darwin" darwinHost;
}
