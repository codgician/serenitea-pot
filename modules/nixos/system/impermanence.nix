{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.system.impermanence;
in
{
  options.codgician.system.impermanence = {
    enable = lib.mkEnableOption "Enable impermanence.";

    path = lib.mkOption {
      type = lib.types.path;
      default = "/nix/persist";
      description = lib.mdDoc ''
        The path where all persistent files should be stored.
      '';
    };

    directories = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [
        "/var/log"
        "/var/lib/acme"
        "/var/lib/bluetooth"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/etc/NetworkManager/system-connections"
        "/home"
      ];
      description = lib.mdDoc ''
        List of extra directories to persist.
      '';
    };

    files = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
      description = lib.mdDoc ''
        List of extra files to persist.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.persistence.${cfg.path} = {
      hideMounts = true;
      directories = cfg.directories;
      files = cfg.files;
    };
  };
}
