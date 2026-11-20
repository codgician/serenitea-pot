{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.anubis;
  inherit (config.codgician.services) nginx;

  # Sites this host proxies through Anubis; nginx sends their traffic here.
  anubisSites = lib.filterAttrs (_: site: site.proxyPass != null && site.anubis) nginx.reverseProxies;

  # systemd service names cannot contain dots.
  sanitizeName = builtins.replaceStrings [ "." ] [ "-" ];

  targetOf = site: site.locations."/".proxyPass or site.proxyPass;

  mkInstance =
    name: site:
    let
      target = targetOf site;
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
  options.codgician.services.anubis = {
    enable = lib.mkEnableOption "Anubis bot protection";
    package = lib.mkPackageOption pkgs "anubis" { };
  };

  config = lib.mkMerge [
    {
      assertions = lib.mapAttrsToList (name: _: {
        assertion = cfg.enable;
        message = ''
          anubis: site "${name}" sets `anubis = true` but this host does not enable Anubis. Set `codgician.services.anubis.enable = true`.
        '';
      }) anubisSites;
    }

    (lib.mkIf cfg.enable {
      # nginx needs access to the Anubis Unix sockets.
      users.users.nginx.extraGroups = [ "anubis" ];

      services.anubis = {
        inherit (cfg) package;
        defaultOptions.settings = {
          DIFFICULTY = 4;
          OG_PASSTHROUGH = true;
          SERVE_ROBOTS_TXT = false;
          # Share challenge passes across subdomains.
          COOKIE_DOMAIN = lib.codgician.zone;
        };

        instances = lib.mapAttrs' (
          name: site: lib.nameValuePair (sanitizeName name) (mkInstance name site)
        ) anubisSites;
      };

      # Inject the signing key into every Anubis instance.
      systemd.services = lib.mapAttrs' (
        name: _:
        lib.nameValuePair "anubis-${sanitizeName name}" {
          serviceConfig.EnvironmentFile = [ config.codgician.secrets.templates."anubis-env".path ];
        }
      ) anubisSites;

      assertions = lib.mapAttrsToList (name: site: {
        assertion = targetOf site != null;
        message = ''anubis: site "${name}" has no upstream for Anubis to protect.'';
      }) anubisSites;
    })
  ];
}
