{ basePkgs, pkgs, ... }:

pkgs.mkShell {
  buildInputs = with pkgs; [
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
  ] ++ basePkgs;
}
