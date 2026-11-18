{ config, lib, ... }:
let
  # Vhosts whose inventory entry asks for Anubis; nginx sends their traffic here.
  anubisProxies = lib.filterAttrs (
    _: vhost: vhost.enable && vhost.anubis.enable
  ) config.codgician.services.nginx.reverseProxies;

  # systemd service names cannot contain dots.
  sanitizeName = builtins.replaceStrings [ "." ] [ "-" ];

  mkInstance =
    name: vhost:
    let
      target = vhost.locations."/".proxyPass or null;
      socketDir = "/run/anubis/anubis-${sanitizeName name}";
    in
    {
      enable = true;
      settings = {
        TARGET = target;
        BIND = "${socketDir}/anubis.sock";
        METRICS_BIND = "${socketDir}/anubis-metrics.sock";
        COOKIE_PARTITIONED = true;
        COOKIE_SECURE = true;
        COOKIE_SAME_SITE = "Lax";
        # HTTPS backends usually have valid certs for their own hostname.
        TARGET_SNI = if target != null && lib.hasPrefix "https://" target then "auto" else null;
      };
    };
in
{
  config = lib.mkIf (anubisProxies != { }) {
    # nginx needs access to the Anubis Unix sockets.
    users.users.nginx.extraGroups = [ "anubis" ];

    services.anubis = {
      defaultOptions.settings = {
        DIFFICULTY = 4;
        OG_PASSTHROUGH = true;
        SERVE_ROBOTS_TXT = false;
        # Share challenge passes across subdomains.
        COOKIE_DOMAIN = lib.codgician.inventory.zone;
      };

      instances = lib.mapAttrs' (
        name: vhost: lib.nameValuePair (sanitizeName name) (mkInstance name vhost)
      ) anubisProxies;
    };

    # Inject the signing key into every Anubis instance.
    systemd.services = lib.mapAttrs' (
      name: _:
      lib.nameValuePair "anubis-${sanitizeName name}" {
        serviceConfig.EnvironmentFile = [ config.codgician.secrets.templates."anubis-env".path ];
      }
    ) anubisProxies;

    assertions = lib.mapAttrsToList (name: vhost: {
      assertion = vhost.locations."/".proxyPass or null != null;
      message = ''anubis: virtual host "${name}" has no upstream for Anubis to protect.'';
    }) anubisProxies;
  };
}
