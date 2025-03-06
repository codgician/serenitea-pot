{ pkgs, ... }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    agenix
    azure-cli
    azure-storage-azcopy
    cf-terraforming
    jq
    hcl2json
    (terraform.withPlugins (p: [
      p.azurerm
      p.cloudflare
      p.proxmox
      p.utils
    ]))
  ];
  shellHook = ''
    echo "Welcome back to serenitea pot!"
  '';
}
