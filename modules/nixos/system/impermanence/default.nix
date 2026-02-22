{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  inherit (lib) types;
  inherit (utils) escapeSystemdPath;
  cfg = config.codgician.system.impermanence;
  persistCfg = config.environment.persistence.${cfg.path};
  persistFs = config.fileSystems.${cfg.path} or null;
  isZfs = persistFs != null && persistFs.fsType == "zfs";
  persistMountUnit = "${escapeSystemdPath cfg.path}.mount";

  # Extract directory paths from final persistence config (includes all modules' additions)
  dirPaths = map (
    d: if builtins.isString d then d else d.directory or d.dirPath
  ) persistCfg.directories;

  # Generate shutdown ordering dropins
  shutdownOrderDropins = pkgs.runCommand "impermanence-shutdown-order-dropins" { } (
    lib.concatMapStrings (dir: ''
      mkdir -p "$out/lib/systemd/system/${escapeSystemdPath dir}.mount.d"
      cat > "$out/lib/systemd/system/${escapeSystemdPath dir}.mount.d/impermanence-shutdown-order.conf" << 'EOF'
        [Unit]
        Before=${persistMountUnit}
      EOF
    '') dirPaths
  );

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
      ]
      ++ lib.optionals (config.services.fail2ban.enable) [ "/var/lib/fail2ban" ]
      ++ lib.optionals (config.services.fwupd.enable) [ "/var/lib/fwupd" ]
      ++ extraDirectories;
      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
      ]
      ++ extraFiles;
    };

    # Install shutdown ordering dropins so bind mounts unmount before persist path
    systemd.packages = lib.mkIf cfg.enable [ shutdownOrderDropins ];
    # Make persist path private to prevent mirror mounts from being created.
    # ZFS mounts bypass systemd mount options, so we run this after zfs-mount.service.
    systemd.services."impermanence-make-persist-private" = lib.mkIf (cfg.enable && isZfs) {
      description = "Make ${cfg.path} mount private to prevent propagation issues";
      wantedBy = [ "local-fs.target" ];
      after = [ "zfs-mount.service" ];
      before = [ "local-fs.target" ];
      unitConfig.ConditionPathIsMountPoint = cfg.path;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "/run/current-system/sw/bin/mount --make-private ${cfg.path}";
      };
    };
  };
}
