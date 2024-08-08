{ config, lib, ... }: {
  imports = [
    ./cognitive
    ./vms
    ./budget.nix
    ./networks.nix
    ./providers.nix
    ./storages.nix
  ];

  resource = {
    # Resource group
    azurerm_resource_group.celestia = {
      location = "japaneast";
      name = "celestia";
    };
  };
}
