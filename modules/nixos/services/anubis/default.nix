{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.anubis;
  nginxCfg = config.codgician.services.nginx;
  ageCfg = config.age.secrets;
  inherit (lib) types optionalAttrs mkIf mkOption mkEnableOption;
  jsonFormat = pkgs.formats.json { };

  # Reverse proxies with Anubis enabled.
  anubisProxies = lib.filterAttrs (_: h: h.enable && h.anubis.enable) nginxCfg.reverseProxies;

  # systemd service names cannot contain dots.
  sanitizeName = builtins.replaceStrings [ "." ] [ "-" ];

  # Extract proxyPass target from the root location, if any.
  proxyTarget = hostCfg: hostCfg.locations."/".passthru.proxyPass or null;

  mkInstance =
    name: hostCfg:
    let
      target = proxyTarget hostCfg;
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
      // optionalAttrs (hostCfg.anubis.difficulty != null) { DIFFICULTY = hostCfg.anubis.difficulty; }
      // optionalAttrs (hostCfg.anubis.ogPassthrough != null) {
        OG_PASSTHROUGH = hostCfg.anubis.ogPassthrough;
      };
    };
in
{
  options.codgician.services.anubis = {
    enable = mkEnableOption "Anubis bot protection";

    defaultDifficulty = mkOption {
      type = types.ints.between 1 7;
      default = 4;
      description = "Default proof-of-work difficulty for all Anubis instances.";
    };

    defaultOgPassthrough = mkOption {
      type = types.bool;
      default = true;
      description = "Allow social media preview bots (Open Graph) by default.";
    };

    defaultServeRobotsTxt = mkOption {
      type = types.bool;
      default = false;
      description = "Serve a restrictive robots.txt that disallows AI scrapers by default.";
    };

    cookieDomain = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "codgician.me";
      description = ''
        Domain for Anubis challenge cookies. Set to your base domain to share
        challenge passes across subdomains.
      '';
    };

    webmasterEmail = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "admin@codgician.me";
      description = "Contact email shown on Anubis error pages.";
    };

    botPolicy = mkOption {
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

  config = mkIf cfg.enable {
    # nginx needs access to the Anubis Unix sockets.
    users.users.nginx.extraGroups = [ "anubis" ];

    # Signing key for cross-subdomain cookie sharing.
    codgician.system.agenix.secrets.anubis-env.owner = "anubis";

    services.anubis = {
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
        name: hostCfg: lib.nameValuePair (sanitizeName name) (mkInstance name hostCfg)
      ) anubisProxies;
    };

    # Inject the signing key into every Anubis instance.
    systemd.services = lib.mapAttrs' (
      name: _:
      lib.nameValuePair "anubis-${sanitizeName name}" {
        serviceConfig.EnvironmentFile = [ ageCfg.anubis-env.path ];
      }
    ) anubisProxies;

    assertions = lib.mapAttrsToList (name: hostCfg: {
      assertion = !hostCfg.anubis.enable || proxyTarget hostCfg != null;
      message = ''
        anubis: Reverse proxy "${name}" has anubis.enable = true but no proxyPass
        configured in locations."/".passthru. Anubis needs a target to protect.
      '';
    }) nginxCfg.reverseProxies;
  };
}
