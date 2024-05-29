{ config, lib, ... }: {
  imports = [
    ./cognitive
    ./vms
    ./budget.nix
    ./network.nix
    ./providers.nix
    ./storage.nix
  ];

  resource = {
    # Resource group
    azurerm_resource_group.celestia = {
      location = "japaneast";
      name = "celestia";
    };
  };
}
