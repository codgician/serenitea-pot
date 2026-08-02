{
  lib,
  pkgs,
  outputs,
  ...
}:

let
  name = builtins.baseNameOf ./.;
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

        # Materialize all credentials once, initialize Terraform, run the requested
        # command with its original argv, then let `secrets run` clean up.
        tf_with_secrets() {
          ${secretsApp} run terraform-env \
            GOOGLE_APPLICATION_CREDENTIALS=gcp-credentials \
            -- ${lib.getExe pkgs.bash} -c '${lib.getExe pkgs.terraform} init && exec "$@"' tfmgr "$@"
        }

        [ $# -gt 0 ] || { show_help; exit 1; }
        command="$1"
        shift

        case "$command" in
          -h|--help)
            show_help
            ;;
          validate)
            tf_config
            tf_with_secrets ${lib.getExe pkgs.terraform} validate "$@"
            ;;
          plan)
            tf_config
            tf_with_secrets ${lib.getExe pkgs.terraform} plan "$@"
            ;;
          apply)
            tf_config
            tf_with_secrets ${lib.getExe pkgs.terraform} apply "$@"
            ;;
          import)
            [ $# -ge 2 ] || err "Usage: ${name} import <addr> <id>"
            tf_config
            tf_with_secrets ${lib.getExe pkgs.terraform} import "$@"
            ;;
          state)
            tf_config
            tf_with_secrets ${lib.getExe pkgs.terraform} state "$@"
            ;;
          shell)
            tf_config
            tf_with_secrets "''${SHELL:-${lib.getExe pkgs.bash}}" "$@"
            ;;
          *)
            warn "Unrecognized command: $command"
            echo ""
            show_help
            exit 1
            ;;
        esac
      '';
    }
  );
}
