{ config, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
in
{
  resource.cloudflare_record = {
    lumine-a = {
      name = "lumine";
      proxied = false;
      ttl = 120;
      comment = "Lumine, on celestia";
      type = "A";
      content = config.resource.azurerm_linux_virtual_machine.lumine "public_ip_addresses[0]";
      inherit zone_id;
    };

    lumine-aaaa = {
      name = "lumine";
      proxied = false;
      ttl = 120;
      comment = "Lumine, on celestia";
      type = "AAAA";
      content = config.resource.azurerm_linux_virtual_machine.lumine "public_ip_addresses[1]";
      inherit zone_id;
    };
  };
}
