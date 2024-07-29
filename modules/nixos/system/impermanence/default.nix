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
      description = ''
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
        "/var/lib/bluetooth"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/etc/NetworkManager/system-connections"
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

    # Clean up persisted files in root partition on boot
    boot.initrd.postMountCommands = let
      mkRmCommand = filePath: "rm -rf /mnt-root/${filePath}";
      commands = builtins.map (x: mkRmCommand x.filePath) config.environment.persistence.${cfg.path}.files;
    in lib.mkBefore (builtins.concatStringsSep "\n" commands);
  };
}
