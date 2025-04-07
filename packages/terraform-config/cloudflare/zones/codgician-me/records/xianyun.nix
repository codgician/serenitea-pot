{ config, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;
in
{
  resource.cloudflare_dns_record = {
    xianyun-a = {
      name = "xianyun.${zone_name}";
      proxied = false;
      ttl = 120;
      comment = "Xianyun, on aocang";
      type = "A";
      content = "1.14.98.187";
      inherit zone_id;
    };

    xianyun-aaaa = {
      name = "xianyun.${zone_name}";
      proxied = false;
      ttl = 120;
      comment = "Xianyun, on aocang";
      type = "AAAA";
      content = "2402:4e00:c000:1900:aa68:cd10:e82c:0";
      inherit zone_id;
    };
  };
}
