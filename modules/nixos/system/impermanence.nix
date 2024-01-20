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
  };

  config = lib.mkIf cfg.enable {
    environment.persistence.${cfg.path} = {
      hideMounts = true;
      directories = [
        "/var/log"
        "/var/lib/acme"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/home"
      ];

      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    };
  };
}
