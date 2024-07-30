# Script for managing terraform configurations

{ lib, pkgs, inputs, outputs, ... }:

let
  binName = builtins.baseNameOf ./.;
  terraformAgeFileName = "terraformEnv.age";
  secretsDir = lib.codgician.secretsDir;
in
inputs.flake-utils.lib.mkApp {
  drv = pkgs.writeShellScriptBin binName ''
    function warn() {
      printf '%s\n' "$*" >&2
    }

    function err() {
      warn "$*"
      exit 1
    }

    # Display help message
    function show_help {
      echo '${binName} - Review and apply terraform configurations in this flake.'
      echo ' '
      echo 'Usage: ${binName} [command]'
      echo ' '
      echo 'Commands:'
      echo ' '
      echo '  validate    Check whether generated config.tf.json is valid'
      echo '  plan        Show infrastructure changes from new configuration'
      echo '  apply       Apply infrastructure changes from new configuration'
      echo ' '
      echo 'Options:'
      echo ' '
      echo ' -h --help    Show this screen'
      echo ' '
    }

    # Init: decrypt terraform secrets and set environment variables
    function init {
      dir=$(${pkgs.coreutils}/bin/pwd)
      cd ${secretsDir}
      
      [ -f "./${terraformAgeFileName}" ] || { 
        err "${terraformAgeFileName} not found under ${secretsDir}"; 
      }

      envs=$(${pkgs.agenix}/bin/agenix -d terraformEnv.age)
      [ ! -z "$envs" ] || { 
        err "Terraform envs should not be empty. Decryption failure?"; 
      }

      export $(echo $envs | xargs)
      cd $dir

      [ ! -e config.tf.json ] || rm -f config.tf.json
      cp ${outputs.packages.${pkgs.system}.terraformConfiguration} config.tf.json
      ${pkgs.terraform}/bin/terraform init
    }

    test $# -eq 0 && (show_help && exit 1)
    while test $# -gt 0; do
      case "$1" in
        -h|--help)
          show_help
          exit 0
          ;;
        validate)
          init
          ${pkgs.terraform}/bin/terraform validate
          ;;
        plan)
          init
          ${pkgs.terraform}/bin/terraform plan
          ;;
        apply)
          init
          ${pkgs.terraform}/bin/terraform apply
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
