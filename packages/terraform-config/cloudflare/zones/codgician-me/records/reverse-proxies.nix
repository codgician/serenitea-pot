{ config, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;
  cnames = [
    "akasha"
    "aranyaka"
    "amt"
    "books"
    "bubbles"
    "fin"
    "git"
    "hass"
    "matrix"
    "pve"
    "gardemek"
    "vanarana"
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
