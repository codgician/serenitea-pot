{ config, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;
  cnames = [
    "akasha"
    "amt"
    "auth"
    "books"
    "bubbles"
    "dendro"
    "dragonspine"
    "fin"
    "git"
    "hass"
    "leyline"
    "lumenstone"
    "matrix"
    "pve"
    "saw"
    "vanarana"
    "vision"
    "voice"
  ];
in
{
  resource.cloudflare_dns_record = builtins.listToAttrs (
    builtins.map (name: {
      name = "${name}-cname";
      value = {
        name = "${name}.${zone_name}";
        proxied = false;
        ttl = 120;
        comment = "Reverse proxied by lumine";
        type = "CNAME";
        content = "lumine.codgician.me";
        inherit zone_id;
      };
    }) cnames
  );
}
