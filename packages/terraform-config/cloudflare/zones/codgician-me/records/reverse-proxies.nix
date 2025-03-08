{ config, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
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
    "saw"
  ];
in
{
  resource.cloudflare_record = builtins.listToAttrs (
    builtins.map (name: {
      name = "${name}-cname";
      value = {
        inherit name zone_id;
        proxied = false;
        ttl = 120;
        comment = "Reverse proxied by lumine";
        type = "CNAME";
        content = "lumine.codgician.me";
      };
    }) cnames
  );
}
