{ config, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;
in
{
  resource.cloudflare_dns_record = {
    lumine-a = {
      name = "lumine.${zone_name}";
      proxied = false;
      ttl = 120;
      comment = "Lumine, on celestia";
      type = "A";
      content = config.resource.azurerm_linux_virtual_machine.lumine "public_ip_addresses[0]";
      inherit zone_id;
    };

    lumine-aaaa = {
      name = "lumine.${zone_name}";
      proxied = false;
      ttl = 120;
      comment = "Lumine, on celestia";
      type = "AAAA";
      content = config.resource.azurerm_linux_virtual_machine.lumine "public_ip_addresses[1]";
      inherit zone_id;
    };

    # Reverse-proxy CNAMEs inherit discovery from this target.
    lumine-https = {
      name = "lumine.${zone_name}";
      type = "HTTPS";
      proxied = false;
      ttl = 120;
      comment = "HTTP/3 discovery for Lumine reverse proxies";
      data = {
        priority = 1;
        target = ".";
        value = ''alpn="h3,h2"'';
      };
      inherit zone_id;
    };
  };
}
