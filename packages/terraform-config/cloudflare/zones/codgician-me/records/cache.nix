{ config, ... }:
let
  zone_id = config.resource.cloudflare_zone.codgician-me "id";
  zone_name = config.resource.cloudflare_zone.codgician-me.name;
  cnames = [ "cache" ];
in
{
  variable.binary_cache_cname = {
    type = "string";
    description = "CNAME target for the binary cache";
  };

  resource.cloudflare_dns_record = builtins.listToAttrs (
    builtins.map (name: {
      name = "${name}-cname";
      value = {
        name = "${name}.${zone_name}";
        proxied = true;
        ttl = 1;
        comment = "Binary Cache";
        type = "CNAME";
        content = "\${var.binary_cache_cname}";
        inherit zone_id;
      };
    }) cnames
  );
}
