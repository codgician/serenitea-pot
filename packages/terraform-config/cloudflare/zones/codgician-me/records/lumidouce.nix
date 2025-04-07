{ config, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;
  cnames = [ "turn" ];
in
{
  resource.cloudflare_dns_record = builtins.listToAttrs (
    builtins.map (name: {
      name = "${name}-cname";
      value = {
        name = "${name}.${zone_name}";
        proxied = false;
        ttl = 120;
        comment = "Lumidouce Harbor";
        type = "CNAME";
        content = "sz.codgician.me";
        inherit zone_id;
      };
    }) cnames
  );
}
