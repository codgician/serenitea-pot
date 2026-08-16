{
  lib,
  pkgs,
  outputs,
  ...
}:

let
  terraform = pkgs.unstable.terraform.withPlugins (
    p: with p; [
      hashicorp_azurerm
      hashicorp_google
      cloudflare_cloudflare
    ]
  );
  tfConfig = outputs.packages.${pkgs.stdenv.hostPlatform.system}.terraform-config;
  secretsApp = outputs.apps.${pkgs.stdenv.hostPlatform.system}.secrets.program;
  terraformShell = pkgs.writeShellScript "terraform-shell" ''
    ${lib.getExe terraform} init || exit
    exec "$SHELL"
  '';
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    sops
    ssh-to-age
    azure-cli
    azure-storage-azcopy
    cf-terraforming
    jq
    hcl2json
    terraform
  ];

  shellHook = ''
    rm -f -- config.tf.json || exit
    cp ${tfConfig} config.tf.json || exit

    exec ${secretsApp} exec-env terraform.json -- ${terraformShell}
  '';
}
