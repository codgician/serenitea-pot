{ lib, pkgs, ... }:
{
  type = "app";
  meta = {
    description = "Utility for jwe file encrypted with TPM2.";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ codgician ];
  };

  program = lib.getExe (
    pkgs.writeShellApplication rec {
      name = builtins.baseNameOf ./.;
      runtimeInputs = with pkgs; [
        clevis
        jose
        tpm2-tools
      ];

      text = ''
        function log_verbose() {
          [ "$VERBOSE" ] && echo "[VERBOSE] $*"
        }

        function warn() {
          printf '%s\n' "$*" >&2
        }

        function err() {
          warn "$*"
          exit 1
        }

        # Display help message
        function show_help {
          echo '${name} - utility for creating jwe file encrypted with TPM2.'
          echo ' '
          echo 'Usage: ${name} [options]'
          echo ' '
          echo 'Options:'
          echo ' '
          echo ' -h --help            Show this screen'
          echo ' -v --verbose         Print verbose logs'
          echo ' --pcr-ids            List of PCR IDs to use for encryption,'
          echo '                      defaults to 1,7,12,14'
          echo ' --pcr-bank           PCR bank to use for encryption,'
          echo '                      defaults to sha256'
          echo ' '
        }

        pcr_ids="1,7,12,14"
        pcr_bank="sha256"
        while [[ $# -gt 0 ]]; do
          case $1 in
            -h|--help)
              show_help
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
              err "Unknown option: $1"
              ;;
          esac
        done

        read -s -r -p "Enter password: " password
        echo  # Move to a new line after password input
        echo "Password entered."

        log_verbose "PCR Bank: $pcr_bank"
        log_verbose "PCR IDs: $pcr_ids"
        echo "$password" | clevis encrypt tpm2 "{\"pcr_bank\":\"$pcr_bank\",\"pcr_ids\":\"$pcr_ids\"}"
      '';
    }
  );
}
