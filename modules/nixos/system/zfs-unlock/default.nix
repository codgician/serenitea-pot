# ZFS TPM2 unlock with anti-confusion and anti-replay protection
#
# Anti-confusion: PCR 15 extended with ZFS fingerprints BEFORE unseal.
#   Fake volumes -> wrong fingerprint -> PCR mismatch -> unseal fails.
# Anti-replay: PCR 15 extended with zeros AFTER unseal.
#   Credential cannot be unsealed again until next reboot.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.system.zfs-unlock;
  zfs = config.boot.zfs.package;

  parseCredsPcrBank = import ./parse-creds.nix { inherit pkgs; };
  zfsFingerprint = import ./zfs-fingerprint.nix {
    inherit pkgs;
    zfsPackage = zfs;
  };

  # Device info: sorted list with derived values computed once
  devices = map (name: rec {
    inherit name;
    safeName = lib.replaceStrings [ "/" ] [ "_" ] name;
    pcrBank = parseCredsPcrBank cfg.devices.${name}.credentialFile;
    credPath = "/etc/zfs-unlock/${safeName}.cred";
    credentialFile = cfg.devices.${name}.credentialFile;
  }) (lib.sort (a: b: a < b) (lib.attrNames cfg.devices));

  usedBanks = lib.unique (map (d: d.pcrBank) devices);

  pcrZerosForBank =
    bank:
    lib.concatStrings (
      lib.replicate
        {
          sha1 = 40;
          sha256 = 64;
          sha384 = 96;
          sha512 = 128;
        }
        .${bank}
        "0"
    );

  tpm2_pcrextend = "${pkgs.tpm2-tools}/bin/tpm2_pcrextend";
  systemd-creds = "${pkgs.systemd}/bin/systemd-creds";
  systemd-ask-password = "${pkgs.systemd}/bin/systemd-ask-password";

  unlockScript = pkgs.writeShellScript "zfs-tpm-unlock" ''
    set -uo pipefail

    pcr_ok=1
    echo "zfs-unlock: Extending PCR 15 with device fingerprints..."
    ${lib.concatMapStrings (d: ''
      echo "zfs-unlock: Computing fingerprint for ${d.name} (bank: ${d.pcrBank})..."
      if fingerprint=$(${zfsFingerprint.script} "${d.name}" ${d.pcrBank} 2>/dev/null); then
        echo "zfs-unlock: PCR extend for ${d.name} (fingerprint: $fingerprint)"
        if ! ${tpm2_pcrextend} "15:${d.pcrBank}=$fingerprint" 2>&1; then
          echo "zfs-unlock: WARNING: PCR extend failed for ${d.name}"
          pcr_ok=0
        fi
      else
        echo "zfs-unlock: WARNING: Fingerprint computation failed for ${d.name}"
        pcr_ok=0
      fi
    '') devices}

    # TPM unlock
    if [[ "$pcr_ok" -eq 1 ]]; then
      ${lib.concatMapStrings (d: ''
        if [[ "$(${zfs}/bin/zfs get -Ho value keystatus "${d.name}" 2>/dev/null)" == "unavailable" ]]; then
          if [[ -f "${d.credPath}" ]]; then
            echo "zfs-unlock: TPM unlock for ${d.name}..."
            if ${systemd-creds} decrypt --name="${d.name}" "${d.credPath}" - 2>/dev/null \
                | ${zfs}/bin/zfs load-key "${d.name}" 2>/dev/null; then
              echo "zfs-unlock: Unlocked ${d.name}"
            else
              echo "zfs-unlock: TPM unlock failed for ${d.name}, will prompt for password"
            fi
          fi
        fi
      '') devices}
    else
      echo "zfs-unlock: Skipping TPM unlock due to PCR errors"
    fi

    # Password fallback
    ${lib.concatMapStrings (d: ''
      if [[ "$(${zfs}/bin/zfs get -Ho value keystatus "${d.name}" 2>/dev/null)" == "unavailable" ]]; then
        kl=$(${zfs}/bin/zfs get -Ho value keylocation "${d.name}" 2>/dev/null)
        if [[ "$kl" == "prompt" ]]; then
          echo "zfs-unlock: Password prompt for ${d.name}"
          for attempt in 1 2 3; do
            if ${systemd-ask-password} --timeout=${toString config.boot.zfs.passwordTimeout} "Enter key for ${d.name}:" \
                | ${zfs}/bin/zfs load-key "${d.name}" 2>/dev/null; then
              echo "zfs-unlock: Unlocked ${d.name}"
              break
            fi
            echo "zfs-unlock: Attempt $attempt failed for ${d.name}"
          done
        fi
      fi
    '') devices}

    # Verify unlock
    all_ok=1
    ${lib.concatMapStrings (d: ''
      if [[ "$(${zfs}/bin/zfs get -Ho value keystatus "${d.name}" 2>/dev/null)" == "unavailable" ]]; then
        echo "zfs-unlock: FATAL: ${d.name} still locked"
        all_ok=0
      fi
    '') devices}
    [[ "$all_ok" -eq 1 ]] || exit 1

    # Anti-replay: extend PCR 15 with zeros to invalidate credential
    echo "zfs-unlock: Anti-replay PCR 15 extension..."
    ${lib.concatMapStrings (bank: ''
      if ! ${tpm2_pcrextend} "15:${bank}=${pcrZerosForBank bank}" 2>&1; then
        echo "zfs-unlock: WARNING: Post-unlock PCR extend failed for bank ${bank}"
      fi
    '') usedBanks}
  '';
in
{
  options.codgician.system.zfs-unlock = {
    enable = lib.mkEnableOption "TPM2-based ZFS unlock with filesystem confusion attack protection";
    devices = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.credentialFile = lib.mkOption {
            type = lib.types.path;
            description = "Path to systemd credential file (.cred) for this dataset.";
          };
        }
      );
      default = { };
      description = "ZFS datasets for PCR 15 fingerprint extension and optional TPM unlock.";
      example = lib.literalExpression "{ zroot.credentialFile = ./zroot.cred; }";
    };
  };

  config = lib.mkIf (cfg.enable && devices != [ ]) {
    assertions = map (d: {
      assertion = lib.any (
        fs: fs.fsType == "zfs" && (fs.device == d.name || lib.hasPrefix "${d.name}/" fs.device)
      ) config.system.build.fileSystems;
      message = "zfs-unlock: Device '${d.name}' has no matching ZFS filesystem.";
    }) devices;

    boot.zfs.requestEncryptionCredentials = lib.mkDefault false;

    boot.initrd.secrets = lib.listToAttrs (
      map (d: {
        name = d.credPath;
        value = d.credentialFile;
      }) devices
    );

    boot.initrd.systemd = {
      enable = true;
      tpm2.enable = true;

      storePaths = [
        tpm2_pcrextend
        unlockScript
        systemd-creds
        systemd-ask-password
        # Password agent for console prompts
        "${config.boot.initrd.systemd.package}/bin/systemd-tty-ask-password-agent"
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
  };
}
