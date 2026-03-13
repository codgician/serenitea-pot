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

  dirPaths = map (
    d: if builtins.isString d then d else d.directory or d.dirPath
  ) persistCfg.directories;

  # Ensure bind mounts are unmounted before persist mount on shutdown
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
      type = types.path;
      default = "/persist";
      description = "The path where all persistent files should be stored.";
    };

    wipeOnShutdown.zfs = {
      enable = lib.mkEnableOption "Wipe ZFS root datasets on shutdown.";

      datasets = lib.mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "zroot/root" ];
        description = ''
          ZFS datasets to rollback on shutdown. If @empty exists, rolls back to it.
          Otherwise bootstraps by destroying and recreating the dataset with @empty.
        '';
      };
    };

    extraItems = lib.mkOption {
      type = types.listOf (
        types.submodule {
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
              description = "Type of the item to persist.";
            };
            user = lib.mkOption {
              type = types.str;
              default = "root";
              description = "Owner of the item.";
            };
            group = lib.mkOption {
              type = types.str;
              default = "root";
              description = "Group of the item.";
            };
            mode = lib.mkOption {
              type = types.str;
              default = "0750";
              description = "Permission mode of the item.";
            };
          };
        }
      );
      default = [ ];
      description = "List of extra items to persist.";
    };
  };

  config = lib.mkMerge [
    {
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
        ++ lib.optionals config.services.fail2ban.enable [ "/var/lib/fail2ban" ]
        ++ lib.optionals config.services.fwupd.enable [ "/var/lib/fwupd" ]
        ++ extraDirectories;
        files = [
          "/etc/machine-id"
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ]
        ++ extraFiles;
      };

      systemd.packages = lib.mkIf cfg.enable [ shutdownOrderDropins ];

      # ZFS bypasses systemd mount options, so we need to make persist private manually
      systemd.services.impermanence-make-persist-private = lib.mkIf (cfg.enable && isZfs) {
        description = "Make ${cfg.path} mount private to prevent propagation issues";
        wantedBy = [ "local-fs.target" ];
        after = [ "zfs-mount.service" ];
        before = [ "local-fs.target" ];
        unitConfig = {
          ConditionPathIsMountPoint = cfg.path;
          DefaultDependencies = false;
        };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "/run/current-system/sw/bin/mount --make-private ${cfg.path}";
        };
      };
    }

    (lib.mkIf cfg.wipeOnShutdown.zfs.enable {
      systemd.shutdownRamfs.contents."/etc/systemd/system-shutdown/impermanence-wipe-zfs".source =
        let
          zfs = config.boot.zfs.package;
          wipeScript = pkgs.writeShellScript "impermanence-wipe-zfs" ''
            set -euo pipefail
            zfs=${zfs}/bin/zfs

            for dataset in ${lib.escapeShellArgs cfg.wipeOnShutdown.zfs.datasets}; do
              if ! $zfs list "$dataset" >/dev/null 2>&1; then
                echo "impermanence: Dataset '$dataset' not found, skipping"
                continue
              fi

              if $zfs list -t snapshot "$dataset@empty" >/dev/null 2>&1; then
                echo "impermanence: Rolling back $dataset to @empty"
                $zfs rollback -r "$dataset@empty"
              else
                echo "impermanence: Bootstrapping $dataset (no @empty found)"
                mountpoint=$($zfs get -H -o value mountpoint "$dataset")
                $zfs destroy -r "$dataset"
                $zfs create -o mountpoint="$mountpoint" "$dataset"
                $zfs snapshot "$dataset@empty"
              fi
            done
          '';
        in
        wipeScript;

      systemd.shutdownRamfs.storePaths = [ "${config.boot.zfs.package}/bin/zfs" ];
    })
  ];
}
