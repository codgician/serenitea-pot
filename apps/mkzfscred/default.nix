{
  lib,
  outputs,
  pkgs,
  ...
}:
let
  # Extract zfs-unlock.devices from all NixOS configurations at build time
  hostDevices = lib.pipe outputs.nixosConfigurations [
    (lib.mapAttrs (
      _: cfg:
      let
        devices = cfg.config.codgician.system.zfs-unlock.devices or { };
      in
      lib.sort (a: b: a < b) (lib.attrNames devices)
    ))
    (lib.filterAttrs (_: devices: devices != [ ]))
  ];

  # Generate bash associative array entries
  hostDevicesStr = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      host: devices: ''["${host}"]="${lib.concatStringsSep " " devices}"''
    ) hostDevices
  );

  # Import shared fingerprint script
  zfsFingerprint = import ../../modules/nixos/system/zfs-unlock/zfs-fingerprint.nix { inherit pkgs; };

  defaultPcrIds = "1+7+12+14+15";
in
{
  type = "app";
  meta = {
    description = "Create TPM2-sealed credentials for ZFS encryption unlock";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ codgician ];
  };

  program = lib.getExe (
    pkgs.writeShellApplication rec {
      name = builtins.baseNameOf ./.;
      runtimeInputs = with pkgs; [
        coreutils
        openssl
        systemd
        tpm2-tools
        xxd
      ];

      text = ''
        set -euo pipefail

        declare -A HOST_DEVICES=(
        ${hostDevicesStr}
        )

        err() { echo "Error: $*" >&2; exit 1; }
        warn() { echo "Warning: $*" >&2; }
        log() { echo "$*" >&2; }

        show_help() {
          cat >&2 <<EOF
        ${name} - Create TPM2-sealed ZFS credentials

        USAGE: ${name} [OPTIONS] <dataset> > output.cred

        PREREQUISITES:
          1. Configure devices in codgician.system.zfs-unlock.devices
          2. Rebuild and reboot (PCR 15 gets extended with fingerprints)

        OPTIONS:
          -h, --help          Show this help
          --pcr-bank BANK     PCR bank (default: sha256)
          --pcr-ids IDS       PCR IDs to bind (default: ${defaultPcrIds})
          --force             Ignore PCR 15 mismatch warning
          --list              List configured devices for this host

        CONFIGURED HOSTS:
        $(for h in "''${!HOST_DEVICES[@]}"; do echo "  $h: ''${HOST_DEVICES[$h]}"; done | sort)
        EOF
        }

        # Compute expected PCR 15: extend(zeros, fp1, fp2, ...)
        compute_expected_pcr15() {
          local bank="$1"; shift
          local pcr zeros

          case "$bank" in
            sha1)   zeros=$(printf '%040d' 0) ;;
            sha256) zeros=$(printf '%064d' 0) ;;
            sha384) zeros=$(printf '%096d' 0) ;;
            sha512) zeros=$(printf '%0128d' 0) ;;
          esac

          pcr="$zeros"
          for dev in "$@"; do
            log "  Fingerprint: $dev"
            local fp
            fp=$(${zfsFingerprint.script} "$dev" "$bank")
            pcr=$(echo -n "$pcr$fp" | xxd -r -p | openssl dgst -"$bank" -binary | xxd -p -c256)
          done
          echo "$pcr"
        }

        # Parse arguments
        pcr_bank="sha256"
        pcr_ids="${defaultPcrIds}"
        force=0
        list_only=0
        dataset=""

        while [[ $# -gt 0 ]]; do
          case $1 in
            -h|--help) show_help; exit 0 ;;
            --pcr-bank) pcr_bank="$2"; shift 2 ;;
            --pcr-ids) pcr_ids="$2"; shift 2 ;;
            --force) force=1; shift ;;
            --list) list_only=1; shift ;;
            -*) err "Unknown option: $1" ;;
            *) [[ -z "$dataset" ]] || err "Only one dataset allowed"; dataset="$1"; shift ;;
          esac
        done

        # Get host's configured devices
        hostname=$(hostname)
        [[ -v "HOST_DEVICES[$hostname]" ]] \
          || err "Host '$hostname' has no zfs-unlock.devices configured"

        # shellcheck disable=SC2206
        all_devices=(''${HOST_DEVICES[$hostname]})

        if [[ "$list_only" -eq 1 ]]; then
          log "Host: $hostname"
          log "Devices: ''${all_devices[*]}"
          exit 0
        fi

        [[ -n "$dataset" ]] || err "Dataset required. Use --help for usage."
        # shellcheck disable=SC2076
        [[ " ''${all_devices[*]} " =~ " $dataset " ]] \
          || err "Dataset '$dataset' not in zfs-unlock.devices for '$hostname'"

        [[ "$pcr_bank" =~ ^(sha1|sha256|sha384|sha512)$ ]] \
          || err "Invalid PCR bank: $pcr_bank"

        [[ -e /dev/tpm0 || -e /dev/tpmrm0 ]] \
          || err "No TPM device found"

        zfs list -Ho name "$dataset" &>/dev/null \
          || err "Dataset '$dataset' not found"

        log "Host: $hostname"
        log "Devices: ''${all_devices[*]}"
        log "Creating credential for: $dataset"
        log ""

        # Verify PCR 15 state
        log "Computing expected PCR 15..."
        expected=$(compute_expected_pcr15 "$pcr_bank" "''${all_devices[@]}")
        current=$(tpm2_pcrread "$pcr_bank:15" 2>/dev/null | grep -oP '15: 0x\K[0-9a-fA-F]+' | tr '[:upper:]' '[:lower:]')

        log "Expected: $expected"
        log "Current:  $current"

        if [[ "$expected" != "$current" ]]; then
          warn "PCR 15 mismatch! Reboot after configuring zfs-unlock.devices."
          [[ "$force" -eq 1 ]] || err "Use --force to proceed anyway (not recommended)"
          warn "Proceeding with --force..."
        fi

        [[ "$pcr_ids" =~ (^|[+])15([+]|$) ]] \
          || warn "PCR 15 not in --pcr-ids; credential may fail to unseal after boot"

        # Create credential (output to stdout)
        log ""
        read -s -r -p "Enter passphrase for $dataset: " secret; echo >&2
        [[ -n "$secret" ]] || err "Passphrase cannot be empty"

        log "Encrypting credential..."
        echo -n "$secret" | systemd-creds encrypt --with-key=tpm2 --tpm2-pcrs="$pcr_ids" --name="$dataset" - - \
          || err "Failed to create credential"

        log ""
        log "Done! Next steps:"
        log "  1. Save output to a .cred file in your host directory"
        log "  2. Set credentialFile = ./<file>.cred in zfs-unlock.devices.$dataset"
        log "  3. Set codgician.system.zfs-unlock.enable = true"
        log "  4. Rebuild and reboot"
      '';
    }
  );
}
