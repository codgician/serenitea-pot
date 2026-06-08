{
  lib,
  pkgs,
  outputs,
  ...
}:

let
  name = builtins.baseNameOf ./.;
  secretsDir = lib.codgician.secretsDir;
  gcpCredsFile = "${secretsDir}/values/gcp-credentials";
  tfConfig = outputs.packages.${pkgs.stdenv.hostPlatform.system}.terraform-config;
  secretsApp = outputs.apps.${pkgs.stdenv.hostPlatform.system}.secrets.program;
in
{
  type = "app";
  meta = {
    description = "Review and apply terraform configurations";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ codgician ];
  };

  program = lib.getExe (
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [
        coreutils
        terraform
        sops
      ];

      text = ''
        set -euo pipefail

        warn() { printf '%s\n' "$*" >&2; }
        err() { warn "$*"; exit 1; }

        show_help() {
          cat <<EOF
        ${name} - review and apply terraform configurations.

        Usage: ${name} [command]

        Commands:
          validate    Check whether generated config.tf.json is valid
          plan        Show infrastructure changes from new configuration
          apply       Apply infrastructure changes from new configuration
          import      Import existing resource into terraform state
          state       Run terraform state subcommands
          shell       Open a shell with terraform env variables

        Options:
          -h --help        Show this screen
          --auto-approve   Auto-approve terraform changes when applying
        EOF
        }

        # Regenerate config.tf.json (contains no secrets, only resource IDs).
        tf_config() {
          [ ! -e config.tf.json ] || rm -f config.tf.json
          cp ${tfConfig} config.tf.json
        }

        # Run a terraform op with secrets in scope. Two unified-model sources,
        # both raw sops values decrypted to 0600 tmpfs files, removed on exit:
        #   - terraform.env text template → rendered to a tmpfs file, sourced as
        #     env vars (ARM_*, CLOUDFLARE_*). The azurerm backend needs ARM_ACCESS_KEY
        #     for `terraform init`, so init runs here too.
        #   - gcp-credentials raw value → decrypted to a tmpfs file;
        #     GOOGLE_APPLICATION_CREDENTIALS points terraform there.
        tf_with_secrets() {
          [ -f "${gcpCredsFile}" ] || err "gcp-credentials missing; run 'nix run .#secrets -- edit gcp-credentials'"
          local env_file gcp_file
          env_file="$(${secretsApp} render terraform.env)" || err "render terraform.env failed"
          umask 077
          gcp_file="$(mktemp "''${XDG_RUNTIME_DIR:-/dev/shm}/tfmgr-gcp.XXXXXX")"
          trap 'rm -f "$env_file" "$gcp_file"' EXIT INT TERM
          sops decrypt --input-type binary --output-type binary "${gcpCredsFile}" > "$gcp_file" \
            || err "decrypt gcp-credentials failed"
          set -a
          # shellcheck disable=SC1090
          source "$env_file"
          GOOGLE_APPLICATION_CREDENTIALS="$gcp_file"
          set +a
          sh -c "terraform init && $*"
        }

        if [ $# -eq 0 ]; then
          show_help
          exit 1
        fi

        tfargs=""
        while [ $# -gt 0 ]; do
          case "$1" in
            -h|--help)
              show_help
              exit 0
              ;;
            --auto-approve)
              tfargs+=" --auto-approve"
              ;;
            validate)
              tf_config
              tf_with_secrets "terraform validate"
              ;;
            plan)
              tf_config
              tf_with_secrets "terraform plan"
              ;;
            apply)
              tf_config
              tf_with_secrets "terraform apply$tfargs || terraform apply$tfargs || terraform apply$tfargs"
              ;;
            import)
              tf_config
              shift
              [ $# -ge 2 ] || err "Usage: ${name} import <addr> <id>"
              tf_with_secrets "terraform import $1 $2"
              shift
              ;;
            state)
              tf_config
              shift
              tf_with_secrets "terraform state $*"
              while [ $# -gt 0 ]; do shift; done
              ;;
            shell)
              tf_config
              tf_with_secrets "''${SHELL:-${lib.getExe pkgs.bash}}"
              ;;
            *)
              warn "Unrecognized command: $1"
              echo ""
              show_help
              exit 1
              ;;
          esac
          shift
        done
      '';
    }
  );
}
