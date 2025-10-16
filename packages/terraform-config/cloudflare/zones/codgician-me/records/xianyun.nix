{ config, lib, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;
  ipv4 = "129.28.44.172";
  ipv6 = "2402:4e00:c000:1400:aa68:cd10:e82c:1";
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
    }));
}
