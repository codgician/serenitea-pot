{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.anubis;
  inherit (config.codgician.services) nginx;
  inherit (lib) types optionalAttrs;
  jsonFormat = pkgs.formats.json { };

  # Sites this host proxies through Anubis; nginx sends their traffic here.
  anubisSites = lib.filterAttrs (
    _: site: site.proxyPass != null && site.anubis.enable
  ) nginx.reverseProxies;

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
      }
      // optionalAttrs (site.anubis.difficulty != null) { DIFFICULTY = site.anubis.difficulty; }
      // optionalAttrs (site.anubis.ogPassthrough != null) {
        OG_PASSTHROUGH = site.anubis.ogPassthrough;
      };
    };
in
{
  options.codgician.services.anubis = {
    enable = lib.mkEnableOption "Anubis bot protection";
    package = lib.mkPackageOption pkgs "anubis" { };

    defaultDifficulty = lib.mkOption {
      type = types.ints.between 1 7;
      default = 4;
      description = "Default proof-of-work difficulty for all Anubis instances.";
    };

    defaultOgPassthrough = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Allow social media preview bots (Open Graph) by default.";
    };

    defaultServeRobotsTxt = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Serve a restrictive robots.txt that disallows AI scrapers by default.";
    };

    cookieDomain = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "codgician.me";
      description = ''
        Domain for Anubis challenge cookies. Set to your base domain to share
        challenge passes across subdomains.
      '';
    };

    webmasterEmail = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "admin@codgician.me";
      description = "Contact email shown on Anubis error pages.";
    };

    botPolicy = lib.mkOption {
      type = types.nullOr jsonFormat.type;
      default = null;
      example = lib.literalExpression ''
        {
          bots = [
            { name = "allow-api"; path_regex = "^/api/.*$"; action = "ALLOW"; }
          ];
        }
      '';
      description = ''
        Global bot policy. Set to null to use Anubis built-in defaults.
        See https://anubis.techaro.lol/docs/admin/policies for details.
      '';
    };
  };

  config = lib.mkMerge [
    {
      assertions = lib.mapAttrsToList (name: _: {
        assertion = cfg.enable;
        message = ''
          anubis: site "${name}" sets `anubis.enable = true` but this host does not enable Anubis. Set `codgician.services.anubis.enable = true`.
        '';
      }) anubisSites;
    }

    (lib.mkIf cfg.enable {
      # nginx needs access to the Anubis Unix sockets.
      users.users.nginx.extraGroups = [ "anubis" ];

      services.anubis = {
        inherit (cfg) package;
        defaultOptions = {
          settings = {
            DIFFICULTY = cfg.defaultDifficulty;
            OG_PASSTHROUGH = cfg.defaultOgPassthrough;
            SERVE_ROBOTS_TXT = cfg.defaultServeRobotsTxt;
          }
          // optionalAttrs (cfg.cookieDomain != null) { COOKIE_DOMAIN = cfg.cookieDomain; }
          // optionalAttrs (cfg.webmasterEmail != null) { WEBMASTER_EMAIL = cfg.webmasterEmail; };
        }
        // optionalAttrs (cfg.botPolicy != null) { policy.settings = cfg.botPolicy; };

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
