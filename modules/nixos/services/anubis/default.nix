{ config, lib, ... }:
let
  inherit (config.codgician.services) nginx;

  # Fronts that ask for Anubis; nginx sends their traffic here.
  anubisFronts = lib.filterAttrs (_: front: front.anubis) nginx.fronts;

  # systemd service names cannot contain dots.
  sanitizeName = builtins.replaceStrings [ "." ] [ "-" ];

  targetOf = name: front: nginx.reverseProxies.${name}.locations."/".proxyPass or front.proxyPass;

  mkInstance =
    name: front:
    let
      target = targetOf name front;
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
  config = lib.mkIf (anubisFronts != { }) {
    # nginx needs access to the Anubis Unix sockets.
    users.users.nginx.extraGroups = [ "anubis" ];

    services.anubis = {
      defaultOptions.settings = {
        DIFFICULTY = 4;
        OG_PASSTHROUGH = true;
        SERVE_ROBOTS_TXT = false;
        # Share challenge passes across subdomains.
        COOKIE_DOMAIN = lib.codgician.zone;
      };

      instances = lib.mapAttrs' (
        name: front: lib.nameValuePair (sanitizeName name) (mkInstance name front)
      ) anubisFronts;
    };

    # Inject the signing key into every Anubis instance.
    systemd.services = lib.mapAttrs' (
      name: _:
      lib.nameValuePair "anubis-${sanitizeName name}" {
        serviceConfig.EnvironmentFile = [ config.codgician.secrets.templates."anubis-env".path ];
      }
    ) anubisFronts;

    assertions = lib.mapAttrsToList (name: front: {
      assertion = targetOf name front != null;
      message = ''anubis: front "${name}" has no upstream for Anubis to protect.'';
    }) anubisFronts;
  };
}
