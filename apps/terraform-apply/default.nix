{ lib, pkgs, inputs, outputs, ... }:

let
  terraformAgeFileName = "terraformEnv.age";
  system = pkgs.system;
  agenixCli = inputs.agenix.packages.${system}.default;
in
# Apply terraform configurations
inputs.flake-utils.lib.mkApp {
  drv = pkgs.writeShellScriptBin "terraform-apply" ''
    # Decrypt terraform secrets and set environment variables
    dir=$(${pkgs.coreutils}/bin/pwd)
    cd ${./secrets}
    
    [ -f "./${terraformAgeFileName}" ] || { 
      echo "${terraformAgeFileName} not found under ${./secrets}"; 
      exit 1; 
    }

    envs=$(${agenixCli}/bin/agenix -d terraformEnv.age)
    [ ! -z "$envs" ] || { 
      echo "Terraform envs should not be empty. Decryption failure?"; 
      exit 1; 
    }

    export $(echo $envs | xargs)
    cd $dir

    # Apply terraform configurations
    [ ! -e config.tf.json ] || rm -f config.tf.json
    cp ${outputs.packages.${system}.terraformConfiguration} config.tf.json \
      && ${pkgs.terraform}/bin/terraform init \
      && ${pkgs.terraform}/bin/terraform apply
  '';
}

