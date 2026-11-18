{ config, lib, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;
  inherit (lib.codgician.inventory) edge;
in
{
  # One CNAME to the edge host for every name in the inventory's service table.
  resource.cloudflare_dns_record = lib.listToAttrs (
    map (
      name:
      lib.nameValuePair "${name}-cname" {
        name = "${name}.${zone_name}";
        proxied = false;
        ttl = 120;
        comment = "Reverse proxied by ${edge}";
        type = "CNAME";
        content = "${edge}.${zone_name}";
        inherit zone_id;
      }
    ) lib.codgician.published.dnsNames
  );
}
