{
  lib,
  pkgs,
  outputs,
  ...
}:

let
  terraformAgeFileName = "terraform-env.age";
  secretsDir = lib.codgician.secretsDir;
in
{
  type = "app";
  meta = {
    description = "Review and apply terraform configurations";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ codgician ];
  };

  program = lib.getExe (
    pkgs.writeShellApplication rec {
      name = builtins.baseNameOf ./.;
      runtimeInputs = with pkgs; [
        coreutils
        terraform
        agenix
      ];

      text = ''
        function warn() {
          printf '%s\n' "$*" >&2
        }

        function err() {
          warn "$*"
          exit 1
        }

        # Display help message
        function show_help {
          echo '${name} - review and apply terraform configurations.'
          echo ' '
          echo 'Usage: ${name} [command]'
          echo ' '
          echo 'Commands:'
          echo ' '
          echo '  validate    Check whether generated config.tf.json is valid'
          echo '  plan        Show infrastructure changes from new configuration'
          echo '  apply       Apply infrastructure changes from new configuration'
          echo '  shell       Open a shell with terraform env variables' 
          echo ' '
          echo 'Options:'
          echo ' '
          echo ' -h --help        Show this screen'
          echo ' --auto-approve   Auto-approve terraform changes when applying'
          echo ' '
        }

        # Init: decrypt terraform secrets and set environment variables
        function init {
          dir=$(pwd)
          cd ${secretsDir}

          [ -f "./${terraformAgeFileName}" ] || { 
            err "${terraformAgeFileName} not found under ${secretsDir}"; 
          }

          envs=$(agenix -d terraform-env.age)
          [ -n "$envs" ] || { 
            err "Terraform envs should not be empty. Decryption failure?"; 
          }

          eval "export $(echo "$envs" | xargs)"
          cd "$dir"

          [ ! -e config.tf.json ] || rm -f config.tf.json
          cp ${outputs.packages.${pkgs.system}.terraform-config} config.tf.json
          terraform init
        }

        if test $# -eq 0; then
          show_help
          exit 1 
        fi

        tfargs=""
        while test $# -gt 0; do
          case "$1" in
            -h|--help)
              show_help
              exit 0
              ;;
            --auto-approve)
              tfargs+=" --auto-approve"
              ;;
            validate)
              init
              terraform validate
              ;;
            plan)
              init
              terraform plan
              ;;
            apply)
              init
              for i in {1..3}; do
                echo "Attempt #$i"
                if eval "terraform apply $tfargs"; then
                  break
                fi
              done
              ;;
            shell)
              init
              if [[ -z $SHELL ]]; then
                warn "SHELL not set, using bash shell"
                SHELL=${lib.getExe pkgs.bash}
              fi
              exec $SHELL
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
