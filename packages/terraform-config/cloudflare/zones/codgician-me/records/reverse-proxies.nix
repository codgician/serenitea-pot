{ config, lib, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;

  # Host the names below resolve to
  edge = "lumine";

  # A name is listed here when a site gets it, whichever host serves the site.
  cnames = [
    "akasha"
    "amt"
    "astrolabe"
    "auth"
    "books"
    "bubbles"
    "dendro"
    "dragonspine"
    "euthymia"
    "fin"
    "git"
    "hass"
    "leyline"
    "lumenstone"
    "matrix"
    "miliastra"
    "moongazer"
    "saw"
    "simulanka"
    "vanarana"
    "vision"
    "voice"
  ];
in
{
  resource.cloudflare_dns_record = lib.genAttrs' cnames (
    name:
    lib.nameValuePair "${name}-cname" {
      name = "${name}.${zone_name}";
      proxied = false;
      ttl = 120;
      comment = "Reverse proxied by ${edge}";
      type = "CNAME";
      content = config.resource.cloudflare_dns_record."${edge}-a".name;
      inherit zone_id;
    }
  );
}
