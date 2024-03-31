{ config, lib, ... }: {
  imports = [
    ./lumine.nix
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
