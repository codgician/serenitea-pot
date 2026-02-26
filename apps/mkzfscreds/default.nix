{
  lib,
  inputs,
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

  # mkcreds binary path
  mkcredsBin = "${inputs.mkcreds.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/mkcreds";

  # Default PCRs: 1 (firmware), 7 (secure boot), 12 (kernel cmdline), 14 (shim MOK), 15 (zfs fingerprint)
  defaultPcrIds = "1,7,12,14,15";
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
        tpm2-tools
        xxd
      ];

      text = ''
                set -euo pipefail

                declare -A HOST_DEVICES=(
                ${hostDevicesStr}
                )

                err() { echo "Error: $*" >&2; exit 1; }
                log() { echo "$*" >&2; }

                show_help() {
                  cat >&2 <<'EOF'
        ${name} - Create TPM2-sealed ZFS credentials with expected PCR 15

        USAGE: ${name} [OPTIONS] <dataset> > output.cred

        This tool seals credentials against the EXPECTED PCR 15 value (computed
        from ZFS fingerprints), allowing enrollment without requiring a reboot.

        WORKFLOW:
          1. Configure devices in codgician.system.zfs-unlock.devices
          2. Run: nix run .#mkzfscreds -- <dataset> > host/<name>.cred
          3. Set credentialFile and enable = true, rebuild
          4. Reboot - automatic unlock works

        OPTIONS:
          -h, --help          Show this help
          --pcr-bank BANK     PCR bank (default: sha256)
          --pcr-ids IDS       Comma-separated PCR IDs (default: ${defaultPcrIds})
                              Must include 15; its value is computed from ZFS fingerprints
          --list              List configured devices for this host
        EOF
          echo >&2
          echo "CONFIGURED HOSTS:" >&2
          # shellcheck disable=SC2043
          for h in "''${!HOST_DEVICES[@]}"; do echo "  $h: ''${HOST_DEVICES[$h]}" >&2; done | sort
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
            local fp
            fp=$(${zfsFingerprint.script} "$dev" "$bank")
            log "  $dev: $fp"
            pcr=$(echo -n "$pcr$fp" | xxd -r -p | openssl dgst -"$bank" -binary | xxd -p -c256)
          done
          echo "$pcr"
        }

        # Parse arguments
        pcr_bank="sha256"
        pcr_ids="${defaultPcrIds}"
        list_only=0
        dataset=""

        while [[ $# -gt 0 ]]; do
          case $1 in
            -h|--help) show_help; exit 0 ;;
            --pcr-bank) pcr_bank="$2"; shift 2 ;;
            --pcr-ids) pcr_ids="$2"; shift 2 ;;
            --list) list_only=1; shift ;;
            -*) err "Unknown option: $1" ;;
            *) [[ -z "$dataset" ]] || err "Only one dataset allowed"; dataset="$1"; shift ;;
          esac
        done

        # Get host's configured devices
        hostname=$(hostname)
        [[ -v "HOST_DEVICES[$hostname]" ]] || err "Host '$hostname' has no zfs-unlock.devices configured"

        # shellcheck disable=SC2206
        all_devices=(''${HOST_DEVICES[$hostname]})

        if [[ "$list_only" -eq 1 ]]; then
          log "Host: $hostname"
          log "Devices: ''${all_devices[*]}"
          exit 0
        fi

        [[ -n "$dataset" ]] || err "Dataset required. Use --help for usage."
        # shellcheck disable=SC2076
        [[ " ''${all_devices[*]} " =~ " $dataset " ]] || err "Dataset '$dataset' not in zfs-unlock.devices for '$hostname'"
        [[ "$pcr_bank" =~ ^(sha1|sha256|sha384|sha512)$ ]] || err "Invalid PCR bank: $pcr_bank"
        [[ ",$pcr_ids," =~ ,15, ]] || err "PCR 15 must be included in --pcr-ids for ZFS fingerprint binding"
        [[ -e /dev/tpm0 || -e /dev/tpmrm0 ]] || err "No TPM device found"
        zfs list -Ho name "$dataset" &>/dev/null || err "Dataset '$dataset' not found"

        log "Creating credential for: $dataset (host: $hostname)"
        log "Devices: ''${all_devices[*]}"
        log "Computing expected PCR 15..."
        expected_pcr15=$(compute_expected_pcr15 "$pcr_bank" "''${all_devices[@]}")
        log "Expected PCR 15: $expected_pcr15"

        # Convert comma-separated to plus-separated, replace 15 with 15:bank=expected
        pcr_spec=$(echo "$pcr_ids" | sed "s/,/+/g; s/15/15:$pcr_bank=$expected_pcr15/")
        log "PCR specification: $pcr_spec"

        read -s -r -p "Enter passphrase for $dataset: " secret; echo >&2
        [[ -n "$secret" ]] || err "Passphrase cannot be empty"

        log "Encrypting credential with mkcreds..."
        echo -n "$secret" | ${mkcredsBin} --tpm2-pcrs="$pcr_spec" - - || err "Failed to create credential"

        log ""
        log "Done! Save output to a .cred file and set credentialFile in zfs-unlock.devices.$dataset"
      '';
    }
  );
}
