{ config, ... }:
let
  svc = config.codgician.inventory.services.coturn;
in
{
  resource.cloudflare_dns_record.turn-cname = {
    zone_id = config.resource.cloudflare_zone.codgician-me "id";
    name = svc.domain;
    type = "CNAME";
    content = config.resource.cloudflare_dns_record."${svc.host}-a".name;
    proxied = false;
    ttl = 120;
    comment = "TURN relay on Xianyun";
  };
}
