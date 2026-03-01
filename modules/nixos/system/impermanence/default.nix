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

  # Extract directory paths from persistence config
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
      type = types.path;
      default = "/persist";
      description = "The path where all persistent files should be stored.";
    };

    wipeOnBoot.zfs = {
      enable = lib.mkEnableOption "Wipe ZFS root datasets on boot.";

      datasets = lib.mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "zroot/root" ];
        description = ''
          List of ZFS root datasets to wipe on boot. For each dataset, a @blank
          snapshot is created on first boot and rolled back to on subsequent boots.

          On first boot (bootstrap), the current state is saved to @last snapshot
          before wiping, allowing recovery of pre-impermanence data.

          NOTE: Do NOT include your persist dataset here.
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
        ]
        ++ extraFiles;
      };

      systemd.packages = lib.mkIf cfg.enable [ shutdownOrderDropins ];

      # Make persist path private to prevent mirror mounts (ZFS bypasses systemd mount options)
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

    # ZFS wipe-on-boot service
    (lib.mkIf cfg.wipeOnBoot.zfs.enable (
      let
        # The service runs after ZFS pools are imported in initrd
        # With systemd initrd, pools listed in boot.zfs.extraPools are imported by zfs-import-<pool>.service
      in
      {
        # Ensure required binaries are available in initrd
        boot.initrd.systemd.storePaths = [
          "${pkgs.util-linux}/bin/mount"
          "${pkgs.util-linux}/bin/umount"
        ];

        boot.initrd.systemd.services.impermanence-wipe-zfs = {
          description = "Snapshot and rollback ZFS datasets for impermanence";
          wantedBy = [ "initrd.target" ];
          after = [ "zfs-import.target" ];
          before = [ "sysroot.mount" ];
          path = [
            config.boot.zfs.package
            pkgs.coreutils
            pkgs.util-linux
          ];
          unitConfig.DefaultDependencies = false;
          serviceConfig.Type = "oneshot";
          script = ''
            wipe_dataset() {
              local dataset="$1"

              if ! zfs list "$dataset" >/dev/null 2>&1; then
                echo "WARNING: Dataset '$dataset' does not exist, skipping"
                return 0
              fi

              echo "Processing dataset: $dataset"

              if zfs list -t snapshot "$dataset@blank" >/dev/null 2>&1; then
                # Normal path: @blank exists, fast rollback
                echo "Rolling back $dataset to @blank"
                zfs rollback -r "$dataset@blank"
              else
                # Bootstrap path: no @blank, need to create it
                echo "No @blank snapshot found - bootstrapping $dataset"

                # Backup current state as snapshot before wiping
                local backup_snapshot="$dataset@last"
                echo "Creating backup snapshot: $backup_snapshot"
                zfs destroy "$backup_snapshot" 2>/dev/null || true
                zfs snapshot "$backup_snapshot"

                # Wipe dataset contents
                mkdir -p /mnt/impermanence-wipe
                mount -t zfs "$dataset" /mnt/impermanence-wipe
                rm -rf /mnt/impermanence-wipe/* /mnt/impermanence-wipe/.[!.]* /mnt/impermanence-wipe/..?* 2>/dev/null || true
                umount /mnt/impermanence-wipe

                # Create the blank snapshot
                zfs snapshot "$dataset@blank"
              fi
            }

            ${lib.concatMapStringsSep "\n" (dataset: "wipe_dataset \"${dataset}\"") cfg.wipeOnBoot.zfs.datasets}
          '';
        };
      }
    ))
  ];
}
