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

    wipeOnShutdown.btrfs = {
      enable = lib.mkEnableOption "Wipe btrfs root subvolumes on shutdown.";

      subvolumes = lib.mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              device = lib.mkOption {
                type = types.str;
                description = "Device path (e.g., /dev/sda1 or /dev/disk/by-label/nixos).";
              };
              subvolume = lib.mkOption {
                type = types.str;
                description = "Subvolume name to wipe (e.g., root). Expects {subvolume}@empty snapshot.";
              };
            };
          }
        );
        default = [ ];
        example = [
          {
            device = "/dev/disk/by-label/nixos";
            subvolume = "root";
          }
        ];
        description = ''
          Btrfs subvolumes to restore on shutdown. If {subvolume}@empty exists, restores from it.
          Otherwise bootstraps by deleting and recreating the subvolume with @empty snapshot.
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

    (lib.mkIf cfg.wipeOnShutdown.btrfs.enable {
      systemd.shutdownRamfs.contents."/etc/systemd/system-shutdown/impermanence-wipe-btrfs".source =
        let
          wipeScript = pkgs.writeShellScript "impermanence-wipe-btrfs" ''
            set -euo pipefail
            btrfs=${pkgs.btrfs-progs}/bin/btrfs
            mount=${pkgs.util-linux}/bin/mount
            umount=${pkgs.util-linux}/bin/umount
            mkdir=${pkgs.coreutils}/bin/mkdir

            # Track mount state for cleanup
            mnt=""
            cleanup() {
              if [ -n "$mnt" ] && mountpoint -q "$mnt" 2>/dev/null; then
                $umount "$mnt" 2>/dev/null || true
              fi
            }
            trap cleanup EXIT

            for entry in ${
              lib.escapeShellArgs (map (s: "${s.device}:${s.subvolume}") cfg.wipeOnShutdown.btrfs.subvolumes)
            }; do
              device="''${entry%%:*}"
              subvolume="''${entry##*:}"

              # Use fixed mount point to avoid mktemp dependency
              mnt="/run/impermanence-btrfs-$$"
              $mkdir -p "$mnt"

              # Try to mount device with subvolid=5 (filesystem root)
              if ! $mount -t btrfs -o subvolid=5 "$device" "$mnt" 2>/dev/null; then
                echo "impermanence: Device '$device' not found or failed to mount, skipping"
                mnt=""
                continue
              fi

              # Check if @empty snapshot exists (proper subvolume check)
              if $btrfs subvolume show "$mnt/$subvolume@empty" >/dev/null 2>&1; then
                echo "impermanence: Rolling back $subvolume from @empty"
                # Delete subvolume recursively (handles nested subvolumes)
                if ! $btrfs subvolume delete -R "$mnt/$subvolume" 2>/dev/null; then
                  # Fallback for older btrfs-progs: simple delete
                  $btrfs subvolume delete "$mnt/$subvolume" || true
                fi
                $btrfs subvolume snapshot "$mnt/$subvolume@empty" "$mnt/$subvolume"
              else
                echo "impermanence: Bootstrapping $subvolume (no @empty snapshot found)"
                # Delete existing subvolume if present
                if $btrfs subvolume show "$mnt/$subvolume" >/dev/null 2>&1; then
                  if ! $btrfs subvolume delete -R "$mnt/$subvolume" 2>/dev/null; then
                    $btrfs subvolume delete "$mnt/$subvolume" || true
                  fi
                fi
                $btrfs subvolume create "$mnt/$subvolume"
                $btrfs subvolume snapshot "$mnt/$subvolume" "$mnt/$subvolume@empty"
              fi

              $umount "$mnt"
              mnt=""
            done
          '';
        in
        wipeScript;

      systemd.shutdownRamfs.storePaths = [
        "${pkgs.btrfs-progs}/bin/btrfs"
        "${pkgs.util-linux}/bin/mount"
        "${pkgs.util-linux}/bin/umount"
        "${pkgs.coreutils}/bin/mkdir"
      ];
    })
  ];
}
