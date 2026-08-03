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

    terraform_secrets_dir="$(${secretsApp} materialize terraform-env \
      GOOGLE_APPLICATION_CREDENTIALS=gcp-credentials)" || exit

    exec {terraform_secrets_lifetime_fd}> >(
      trap "" HUP INT TERM
      ${pkgs.coreutils}/bin/cat >/dev/null
      ${pkgs.coreutils}/bin/rm -rf -- "$terraform_secrets_dir"
    ) || {
      ${pkgs.coreutils}/bin/rm -rf -- "$terraform_secrets_dir"
      exit 1
    }

    terraform_allexport_was_set=
    [[ $- == *a* ]] && terraform_allexport_was_set=1
    set -a
    # shellcheck disable=SC1090
    if ! source "$terraform_secrets_dir/environment"; then
      exit 1
    fi
    [ -n "$terraform_allexport_was_set" ] || set +a
    unset terraform_allexport_was_set terraform_secrets_dir

    ${lib.getExe terraform} init || exit
  '';
}
