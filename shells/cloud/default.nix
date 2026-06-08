{ pkgs, ... }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    sops
    ssh-to-age
    azure-cli
    azure-storage-azcopy
    cf-terraforming
    jq
    hcl2json
    (terraform.withPlugins (
      p: with p; [
        hashicorp_azurerm
        hashicorp_google
        cloudflare_cloudflare
        telmate_proxmox
        cloudposse_utils
      ]
    ))
  ];
  shellHook = ''
    echo "Welcome back to serenitea pot!"
  '';
}
