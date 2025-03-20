{ ... }:
{
  imports = [
    ./cognitive
    ./storages
    ./vms
    ./budget.nix
    ./networks.nix
    ./providers.nix
    ./gallery.nix
  ];

  resource = {
    # Resource group
    azurerm_resource_group.celestia = {
      location = "japaneast";
      name = "celestia";
    };
  };
}
