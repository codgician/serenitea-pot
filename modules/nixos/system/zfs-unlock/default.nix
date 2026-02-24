# ZFS TPM2 unlock module with filesystem confusion attack protection
#
# Security model:
#   - PCR 15 is extended with ZFS crypto metadata fingerprints BEFORE unsealing
#   - Fingerprints computed in deterministic (sorted) order
#   - If fingerprint doesn't match (fake volume), PCR 15 differs, unseal fails
#
# Enrollment workflow:
#   1. Configure devices (enable can be false)
#   2. Rebuild and reboot (PCR 15 gets extended)
#   3. Run: nix run .#mkzfscred -- <dataset>
#   4. Set enable = true, add credentialFile, rebuild
#   5. Reboot - automatic unlock works
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.system.zfs-unlock;
  zfs = config.boot.zfs.package;

  sortedDevices = lib.sort (a: b: a < b) (lib.attrNames cfg.devices);
  devicesWithCreds = lib.filter (d: cfg.devices.${d}.credentialFile != null) sortedDevices;
  safeName = d: lib.replaceStrings [ "/" ] [ "_" ] d;

  # Shared fingerprint script and its dependencies
  zfsFingerprint = import ./zfs-fingerprint.nix {
    inherit pkgs;
    zfsPackage = zfs;
  };

  # Helper paths
  tpm2_pcrextend = "${pkgs.tpm2-tools}/bin/tpm2_pcrextend";
  systemd-creds = "${pkgs.systemd}/bin/systemd-creds";
  systemd-ask-password = "${pkgs.systemd}/bin/systemd-ask-password";

  unlockScript = pkgs.writeShellScript "zfs-tpm-unlock" ''
    set -uo pipefail  # Note: no -e, we handle errors manually for resilience

    pcr_ok=1
    echo "zfs-unlock: Extending PCR 15 with device fingerprints..."
    for dataset in ${lib.concatStringsSep " " sortedDevices}; do
      echo "zfs-unlock: Computing fingerprint for $dataset..."
      if fingerprint=$(${zfsFingerprint.script} "$dataset" sha256 2>/dev/null); then
        echo "zfs-unlock: PCR extend for $dataset (fingerprint: $fingerprint)"
        if ! ${tpm2_pcrextend} "15:sha256=$fingerprint" 2>&1; then
          echo "zfs-unlock: WARNING: PCR extend failed for $dataset"
          pcr_ok=0
        fi
      else
        echo "zfs-unlock: WARNING: Fingerprint computation failed for $dataset"
        pcr_ok=0
      fi
    done

    ${lib.optionalString (devicesWithCreds != [ ]) ''
      # TPM unlock (only if PCR extension succeeded)
      if [[ "$pcr_ok" -eq 1 ]]; then
        ${lib.concatMapStrings (ds: ''
          if [[ "$(${zfs}/bin/zfs get -Ho value keystatus "${ds}" 2>/dev/null)" == "unavailable" ]]; then
            cred="/etc/zfs-unlock/${safeName ds}.cred"
            if [[ -f "$cred" ]]; then
              echo "zfs-unlock: TPM unlock for ${ds}..."
              if ${systemd-creds} decrypt --name="${ds}" "$cred" - 2>/dev/null \
                  | ${zfs}/bin/zfs load-key "${ds}" 2>/dev/null; then
                echo "zfs-unlock: Unlocked ${ds}"
              else
                echo "zfs-unlock: TPM unlock failed for ${ds}, will prompt for password"
              fi
            fi
          fi
        '') devicesWithCreds}
      else
        echo "zfs-unlock: Skipping TPM unlock due to PCR errors"
      fi

      # Password fallback for remaining locked datasets
      for ds in ${lib.concatStringsSep " " sortedDevices}; do
        ks=$(${zfs}/bin/zfs get -Ho value keystatus "$ds" 2>/dev/null || echo "unavailable")
        if [[ "$ks" == "unavailable" ]]; then
          kl=$(${zfs}/bin/zfs get -Ho value keylocation "$ds" 2>/dev/null)
          [[ "$kl" == "prompt" ]] || continue
          echo "zfs-unlock: Password prompt for $ds"
          for attempt in 1 2 3; do
            if ${systemd-ask-password} --timeout=${toString config.boot.zfs.passwordTimeout} "Enter key for $ds:" \
                | ${zfs}/bin/zfs load-key "$ds" 2>/dev/null; then
              echo "zfs-unlock: Unlocked $ds"
              break
            fi
            echo "zfs-unlock: Attempt $attempt failed for $ds"
          done
        fi
      done

      # Verify all datasets unlocked
      all_ok=1
      for ds in ${lib.concatStringsSep " " sortedDevices}; do
        ks=$(${zfs}/bin/zfs get -Ho value keystatus "$ds" 2>/dev/null || echo "unavailable")
        if [[ "$ks" == "unavailable" ]]; then
          echo "zfs-unlock: FATAL: $ds still locked"
          all_ok=0
        fi
      done
      [[ "$all_ok" -eq 1 ]] || exit 1
    ''}
  '';
in
{
  options.codgician.system.zfs-unlock = {
    enable = lib.mkEnableOption "TPM2-based ZFS unlock with filesystem confusion attack protection";

    devices = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.credentialFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Path to systemd credential file (.cred) for this dataset.";
          };
        }
      );
      default = { };
      description = "ZFS datasets for PCR 15 fingerprint extension and optional TPM unlock.";
      example = lib.literalExpression "{ zroot.credentialFile = ./zroot.cred; }";
    };
  };

  config = lib.mkIf (cfg.devices != { }) (
    lib.mkMerge [
      {
        boot.initrd.systemd = {
          enable = true;
          tpm2.enable = true;

          storePaths = [
            tpm2_pcrextend
            unlockScript
          ]
          ++ zfsFingerprint.storePaths;

          services.zfs-tpm-unlock = {
            description = "ZFS TPM2 unlock with PCR 15 fingerprint extension";
            # Run after ZFS pools are imported
            after = [ "zfs-import.target" ];
            # Must complete before root filesystem mount
            before = [
              "sysroot.mount"
              "initrd-root-fs.target"
            ];
            wantedBy = [ "sysroot.mount" ];
            # Prevent starting during switch-root
            conflicts = [ "initrd-switch-root.target" ];
            unitConfig.DefaultDependencies = false;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = toString unlockScript;
          };
        };
      }

      (lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = devicesWithCreds != [ ];
            message = "zfs-unlock: enable = true but no devices have credentialFile set.";
          }
        ]
        ++ (map (ds: {
          assertion = lib.any (
            fs: fs.fsType == "zfs" && (fs.device == ds || lib.hasPrefix "${ds}/" fs.device)
          ) config.system.build.fileSystems;
          message = "zfs-unlock: Device '${ds}' has no matching ZFS filesystem.";
        }) (lib.attrNames cfg.devices));

        boot.zfs.requestEncryptionCredentials = lib.mkDefault false;

        boot.initrd.secrets = lib.listToAttrs (
          map (ds: {
            name = "/etc/zfs-unlock/${safeName ds}.cred";
            value = cfg.devices.${ds}.credentialFile;
          }) devicesWithCreds
        );

        boot.initrd.systemd.storePaths = [
          systemd-creds
          systemd-ask-password
          # Password agent for console prompts
          "${config.boot.initrd.systemd.package}/bin/systemd-tty-ask-password-agent"
        ];
      })
    ]
  );
}
