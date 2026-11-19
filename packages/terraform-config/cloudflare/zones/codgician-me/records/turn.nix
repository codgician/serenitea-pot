{ config, ... }:
{
  resource.cloudflare_dns_record.turn-cname = {
    zone_id = config.resource.cloudflare_zone.codgician-me "id";
    name = "turn.${config.resource.cloudflare_zone.codgician-me.name}";
    type = "CNAME";
    content = config.resource.cloudflare_dns_record.xianyun-a.name;
    proxied = false;
    ttl = 120;
    comment = "TURN relay on Xianyun";
  };
}
