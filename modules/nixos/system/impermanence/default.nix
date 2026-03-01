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
          List of ZFS root datasets to rollback on boot. For each dataset:

          Normal path (@blank exists): Fast rollback to @blank snapshot.

          Bootstrap path (no @blank): Creates @last backup, wipes contents,
          creates @blank. This happens automatically on first boot when @blank
          doesn't exist (e.g., existing system enabling impermanence).

          The @blank snapshot can also be pre-created by disko's postCreateHook
          during initial disk setup to skip the bootstrap path.

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
    (lib.mkIf cfg.wipeOnBoot.zfs.enable {
      # Ensure mount/umount are available in initrd for bootstrap path
      boot.initrd.systemd.storePaths = [
        "${pkgs.util-linux}/bin/mount"
        "${pkgs.util-linux}/bin/umount"
        "${pkgs.findutils}/bin/find"
      ];

      boot.initrd.systemd.services.impermanence-wipe-zfs = {
        description = "Rollback ZFS datasets for impermanence";
        wantedBy = [ "initrd.target" ];
        after = [ "zfs-import.target" ];
        before = [ "sysroot.mount" ];
        path = [
          config.boot.zfs.package
          pkgs.coreutils
          pkgs.util-linux
          pkgs.findutils
        ];
        unitConfig.DefaultDependencies = false;
        serviceConfig.Type = "oneshot";
        script = ''
          needs_reboot=false

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

              # Backup current state
              echo "Creating backup snapshot: $dataset@last"
              zfs destroy "$dataset@last" 2>/dev/null || true
              zfs snapshot "$dataset@last"

              # Get original mountpoint
              local orig_mp
              orig_mp=$(zfs get -H -o value mountpoint "$dataset")

              # Use trap to restore mountpoint on any failure
              cleanup() {
                if [ "$orig_mp" != "legacy" ] && [ "$orig_mp" != "none" ]; then
                  zfs set mountpoint="$orig_mp" "$dataset" 2>/dev/null || true
                fi
              }
              trap cleanup EXIT

              # Temporarily set to legacy for manual mount
              if [ "$orig_mp" != "legacy" ] && [ "$orig_mp" != "none" ]; then
                zfs set mountpoint=legacy "$dataset"
              fi

              # Wipe contents
              mkdir -p /mnt/impermanence-wipe
              mount -t zfs "$dataset" /mnt/impermanence-wipe
              find /mnt/impermanence-wipe -mindepth 1 -delete 2>/dev/null || true
              umount /mnt/impermanence-wipe

              # Restore original mountpoint
              trap - EXIT
              if [ "$orig_mp" != "legacy" ] && [ "$orig_mp" != "none" ]; then
                zfs set mountpoint="$orig_mp" "$dataset"
              fi

              # Create blank snapshot
              echo "Creating blank snapshot: $dataset@blank"
              zfs snapshot "$dataset@blank"

              # Mark for reboot to ensure clean boot with @blank
              needs_reboot=true
            fi
          }

          ${lib.concatMapStringsSep "\n" (dataset: "wipe_dataset \"${dataset}\"") cfg.wipeOnBoot.zfs.datasets}

          # Note: No reboot needed. After bootstrap:
          # 1. Dataset is unmounted (we did umount)
          # 2. Mountpoint property restored to original
          # 3. @blank snapshot now exists
          # 4. sysroot.mount runs next and mounts normally
        '';
      };
    })
  ];
}
