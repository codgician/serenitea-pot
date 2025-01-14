{ config, lib, ... }:
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

  config = {
    environment.persistence.${cfg.path} = {
      inherit (cfg) enable;
      hideMounts = true;
      directories = [
        "/var/log"
        "/var/lib/acme"
        "/var/lib/bluetooth"
        "/var/lib/nixos"
        {
          directory = "/var/lib/private";
          mode = "0700";
        }
        "/var/lib/systemd/coredump"
        "/etc/NetworkManager/system-connections"
        "/home"
      ];
      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
      ];
    };

    # Clean up persisted files in root partition on boot
    boot.initrd.postMountCommands = lib.mkIf cfg.enable (
      lib.pipe config.environment.persistence.${cfg.path}.files [
        (builtins.map (x: "rm -rf /mnt-root/${x.filePath}"))
        (builtins.concatStringsSep "\n")
        lib.mkBefore
      ]
    );

    # Suppress systemd-machine-id-commit service
    systemd.suppressedSystemUnits = lib.mkIf cfg.enable [
      "systemd-machine-id-commit.service"
    ];
  };
}
