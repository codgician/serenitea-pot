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
          if [ "$VERBOSE" -eq 1 ]; then echo "[VERBOSE] $*"; fi
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

        # Display TPM subcommand help
        function show_tpm_help {
          echo "${name} tpm - encrypt with TPM2"
          echo
          echo "Usage: ${name} tpm [options]"
          echo
          echo "Options:"
          echo "  -h, --help      Show this screen"
          echo "  -v, --verbose   Print verbose logs"
          echo "  --pcr-ids IDS   Comma-separated list of PCR IDs (default: 1,2,7,12,14)"
          echo "  --pcr-bank BANK PCR bank to use (default: sha256)"
          echo
          echo "Example:"
          echo "  ${name} tpm --pcr-bank sha384 --pcr-ids 7"
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
          local pcr_ids="1,2,7,12,14"
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

          read -s -r -p "Enter password: " password
          echo >&2
          echo "Password entered." >&2

          log_verbose "PCR Bank: $pcr_bank"
          log_verbose "PCR IDs: $pcr_ids"
          echo "$password" | clevis encrypt tpm2 "{\"pcr_bank\":\"$pcr_bank\",\"pcr_ids\":\"$pcr_ids\"}"
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
