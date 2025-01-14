{ config, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  cnames = [ "turn" ];
in
{
  resource.cloudflare_record = builtins.listToAttrs (
    builtins.map (name: {
      name = "${name}-cname";
      value = {
        inherit name zone_id;
        proxied = false;
        ttl = 120;
        comment = "Lumidouce Harbor";
        type = "CNAME";
        content = "sz.codgician.me";
      };
    }) cnames
  );
}
