{ config, lib, ... }:
let
  inherit (lib) types;
  cfg = config.codgician.system.impermanence;

  extraDirectories = lib.pipe cfg.extraItems [
    (builtins.filter (x: x.type == "directory"))
    (builtins.map (x: {
      directory = x.path;
      inherit (x) user group mode;
    }))
  ];
  extraFiles = lib.pipe cfg.extraItems [
    (builtins.filter (x: x.type == "file"))
    (builtins.map (x: {
      file = x.path;
      inherit (x) user group mode;
    }))
  ];
in
{
  options.codgician.system.impermanence = {
    enable = lib.mkEnableOption "Impermanence.";

    path = lib.mkOption {
      type = lib.types.path;
      default = "/persist";
      description = ''
        The path where all persistent files should be stored.
      '';
    };

    extraItems = lib.mkOption {
      type =
        with types;
        listOf (submodule {
          options = {
            path = lib.mkOption {
              type = types.path;
              description = "Path to the directory or file to persist.";
            };

            type = lib.mkOption {
              type = types.enum [
                "file"
                "directory"
              ];
              description = ''
                Type of the item to persist.
                If set to "file", the item will be treated as a file.
                If set to "directory", the item will be treated as a directory.
              '';
            };

            user = lib.mkOption {
              type = types.str;
              default = "root";
              description = ''
                Owner of the item to persist.
                This will be used to set the ownership of the item after it is copied.
              '';
            };

            group = lib.mkOption {
              type = types.str;
              default = "root";
              description = ''
                Group of the item to persist.
              '';
            };

            mode = lib.mkOption {
              type = types.str;
              default = "0750";
              description = ''
                Permission mode of the item to persist.
              '';
            };
          };
        });
      default = [ ];
      description = ''
        List of extra items to persist.
      '';
    };
  };

  config = {
    environment.persistence.${cfg.path} = {
      inherit (cfg) enable;
      hideMounts = true;
      directories =
        [
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
        ]
        ++ lib.optionals (config.services.fail2ban.enable) [ "/var/lib/fail2ban" ]
        ++ lib.optionals (config.services.fwupd.enable) [ "/var/lib/fwupd" ]
        ++ extraDirectories;
      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
      ] ++ extraFiles;
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
