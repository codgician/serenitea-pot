{ lib, pkgs, ... }:
{
  type = "app";
  meta = {
    description = "Utility for creating JWE files encrypted with TPM2 or Tang for disk auto-unlock.";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ codgician ];
  };

  program = lib.getExe (
    pkgs.writeShellApplication rec {
      name = builtins.baseNameOf ./.;
      runtimeInputs = with pkgs; [
        clevis
        curl
        jose
        tpm2-tools
      ];

      text = ''
        VERBOSE=0
        function log_verbose() {
          if [ "$VERBOSE" -eq 1 ]; then echo "[VERBOSE] $*" >&2; fi
        }

        function warn() {
          printf '%s\n' "$*" >&2
        }

        function err() {
          warn "$*"
          exit 1
        }

        # Display main help message
        function show_help {
          echo "${name} - utility for creating JWE files for disk auto-unlock."
          echo
          echo "Usage: ${name} <command> [options]"
          echo
          echo "Commands:"
          echo "  tpm     Encrypt with TPM2 (binds to PCR values)"
          echo "  tang    Encrypt with Tang server (network-based unlock)"
          echo
          echo "Options:"
          echo "  -h, --help      Show this screen"
          echo "  -v, --verbose   Print verbose logs"
          echo
          echo "Run '${name} <command> --help' for command-specific options."
          echo
          echo "Examples:"
          echo "  ${name} tpm --pcr-ids 7"
          echo "  ${name} tang --url http://192.168.6.1:9090"
        }

        # Default PCR IDs for TPM binding
        DEFAULT_PCR_IDS="1,7,12,14,15"
        # PCR hash sizes in bytes for each bank
        declare -A PCR_HASH_SIZES=(
          [sha1]=20
          [sha256]=32
          [sha384]=48
          [sha512]=64
        )

        # Build PCR digest with PCR 15 forced to zeros
        # This is necessary because at enrollment time PCR 15 may already be extended,
        # but at initrd decryption time it will still be zeros (pre-extension state)
        function build_pcr_digest {
          local pcr_bank="$1"
          local pcr_ids="$2"
          local tmpdir
          tmpdir=$(mktemp -d)
          trap 'rm -rf "$tmpdir"' RETURN

          # Build the concatenated PCR values in PCR ID order
          # For PCR 15, use zeros; for others, read from TPM
          local digest_file="$tmpdir/pcr.digest"
          true > "$digest_file"

          # Sort PCR IDs numerically and iterate
          local sorted_ids
          sorted_ids=$(echo "$pcr_ids" | tr ',' '\n' | sort -n | tr '\n' ',' | sed 's/,$//')

          IFS=',' read -ra pcr_array <<< "$sorted_ids"
          for pcr_id in "''${pcr_array[@]}"; do
            if [[ "$pcr_id" == "15" ]]; then
              # Use zeros for PCR 15 (pre-extension state)
              log_verbose "PCR 15: using zeros (pre-extension state)"
              dd if=/dev/zero bs="''${PCR_HASH_SIZES[$pcr_bank]}" count=1 2>/dev/null >> "$digest_file"
            else
              # Read current value from TPM
              log_verbose "PCR $pcr_id: reading from TPM"
              tpm2_pcrread -Q "$pcr_bank:$pcr_id" -o "$tmpdir/pcr_$pcr_id.bin"
              cat "$tmpdir/pcr_$pcr_id.bin" >> "$digest_file"
            fi
          done

          # Output base64url-encoded digest (jose uses base64url, not standard base64)
          jose b64 enc -I "$digest_file"
        }
        # Display TPM subcommand help
        function show_tpm_help {
          echo "${name} tpm - encrypt with TPM2"
          echo
          echo "Usage: ${name} tpm [options]"
          echo
          echo "Options:"
          echo "  -h, --help      Show this screen"
          echo "  -v, --verbose   Print verbose logs"
          echo "  --pcr-ids IDS   Comma-separated list of PCR IDs (default: $DEFAULT_PCR_IDS)"
          echo "  --pcr-bank BANK PCR bank to use (default: sha256)"
          echo
          echo "NOTE: PCR 15 is automatically enrolled with its pre-extension (zero) value,"
          echo "      so the policy will match during initrd before PCR 15 is extended."
          echo
          echo "Example:"
          echo "  ${name} tpm --pcr-bank sha384 --pcr-ids 7,15"
        }

        # Display Tang subcommand help
        function show_tang_help {
          echo "${name} tang - encrypt with Tang server"
          echo
          echo "Usage: ${name} tang [options]"
          echo
          echo "Options:"
          echo "  -h, --help      Show this screen"
          echo "  -v, --verbose   Print verbose logs"
          echo "  --url URL       Tang server URL (required)"
          echo "  --thp THP       Tang server thumbprint for verification (optional)"
          echo "                  If not provided, will prompt to trust the server"
          echo
          echo "Example:"
          echo "  ${name} tang --url http://192.168.6.1:9090"
        }

        # TPM encryption
        function do_tpm {
          local pcr_ids="$DEFAULT_PCR_IDS"
          local pcr_bank="sha256"

          while [[ $# -gt 0 ]]; do
            case $1 in
              -h|--help)
                show_tpm_help
                exit 0
                ;;
              -v|--verbose)
                export VERBOSE=1
                shift
                ;;
              --pcr-ids)
                pcr_ids="$2"
                shift 2
                ;;
              --pcr-bank)
                pcr_bank="$2"
                shift 2
                ;;
              *)
                err "Unknown option for tpm: $1"
                ;;
            esac
          done

          # Warn if PCR 15 is not included (filesystem confusion mitigation)
          if [[ ! ",$pcr_ids," =~ ,15, ]]; then
            warn "WARNING: PCR 15 not included in --pcr-ids."
            warn "         This leaves the system vulnerable to filesystem confusion attacks."
            warn ""
          fi

          read -s -r -p "Enter password: " password
          echo >&2
          echo "Password entered." >&2
          log_verbose "PCR Bank: $pcr_bank"
          log_verbose "PCR IDs: $pcr_ids"
          # Build clevis config
          local clevis_config
          if [[ ",$pcr_ids," =~ ,15, ]]; then
            # PCR 15 is included - use pcr_digest to specify pre-extension (zero) value
            local pcr_digest
            pcr_digest=$(build_pcr_digest "$pcr_bank" "$pcr_ids")
            log_verbose "PCR Digest (base64): $pcr_digest"
            clevis_config="{\"pcr_bank\":\"$pcr_bank\",\"pcr_ids\":\"$pcr_ids\",\"pcr_digest\":\"$pcr_digest\"}"
          else
            # No PCR 15 - use current TPM values
            clevis_config="{\"pcr_bank\":\"$pcr_bank\",\"pcr_ids\":\"$pcr_ids\"}"
          fi

          echo "$password" | clevis encrypt tpm2 "$clevis_config"
        }

        # Tang encryption
        function do_tang {
          local url=""
          local thp=""

          while [[ $# -gt 0 ]]; do
            case $1 in
              -h|--help)
                show_tang_help
                exit 0
                ;;
              -v|--verbose)
                export VERBOSE=1
                shift
                ;;
              --url)
                url="$2"
                shift 2
                ;;
              --thp)
                thp="$2"
                shift 2
                ;;
              *)
                err "Unknown option for tang: $1"
                ;;
            esac
          done

          if [[ -z "$url" ]]; then
            err "Error: --url is required for tang encryption"
          fi

          read -s -r -p "Enter password: " password
          echo >&2
          echo "Password entered." >&2

          log_verbose "Tang URL: $url"

          local clevis_config
          if [[ -n "$thp" ]]; then
            log_verbose "Tang thumbprint: $thp"
            clevis_config="{\"url\":\"$url\",\"thp\":\"$thp\"}"
          else
            clevis_config="{\"url\":\"$url\"}"
          fi

          echo "$password" | clevis encrypt tang "$clevis_config"
        }

        # Main entry point
        if [[ $# -eq 0 ]]; then
          show_help
          exit 1
        fi

        case $1 in
          -h|--help)
            show_help
            exit 0
            ;;
          -v|--verbose)
            export VERBOSE=1
            shift
            if [[ $# -eq 0 ]]; then
              show_help
              exit 1
            fi
            ;;&
          tpm)
            shift
            do_tpm "$@"
            ;;
          tang)
            shift
            do_tang "$@"
            ;;
          *)
            err "Unknown command: $1. Run '${name} --help' for usage."
            ;;
        esac
      '';
    }
  );
}
