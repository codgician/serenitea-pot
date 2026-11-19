{ config, lib, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;
  inherit (config.codgician.inventory.hosts.xianyun) ipv4 ipv6;
in
{
  resource.cloudflare_dns_record =
    (lib.genAttrs [ "xianyun-a" "xianyun4-a" ] (name: {
      name = "${lib.removeSuffix "-a" name}.${zone_name}";
      proxied = false;
      ttl = 120;
      comment = "Xianyun, on Aocang";
      type = "A";
      content = ipv4;
      inherit zone_id;
    }))
    // (lib.genAttrs [ "xianyun-aaaa" "xianyun6-aaaa" ] (name: {
      name = "${lib.removeSuffix "-aaaa" name}.${zone_name}";
      proxied = false;
      ttl = 120;
      comment = "Xianyun, on Aocang";
      type = "AAAA";
      content = ipv6;
      inherit zone_id;
    }))
    // (lib.genAttrs [ "xianyun-https" "xianyun4-https" "xianyun6-https" ] (name: {
      name = "${lib.removeSuffix "-https" name}.${zone_name}";
      type = "HTTPS";
      proxied = false;
      ttl = 120;
      comment = "HTTP/3 discovery for Xianyun";
      data = {
        priority = 1;
        target = ".";
        value = ''alpn="h3,h2"'';
      };
      inherit zone_id;
    }));
}
