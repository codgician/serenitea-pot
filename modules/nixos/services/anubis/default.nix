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
  types = lib.types;
  jsonFormat = pkgs.formats.json { };

  # Collect all reverse proxies with anubis enabled
  anubisEnabledProxies = lib.filterAttrs (
    _: hostCfg: hostCfg.enable && hostCfg.anubis.enable
  ) nginxCfg.reverseProxies;

  # Sanitize name for use as systemd service name
  sanitizeName = name: builtins.replaceStrings [ "." ] [ "-" ] name;

  # Get the target URL from a reverse proxy config
  # Looks for proxyPass in the root location's passthru
  getTargetFromProxy =
    hostCfg:
    let
      rootLocation = hostCfg.locations."/" or { };
      passthru = rootLocation.passthru or { };
    in
    passthru.proxyPass or null;

  # Generate Anubis instance config from a reverse proxy
  mkAnubisInstance =
    name: hostCfg:
    let
      instanceName = sanitizeName name;
      target = getTargetFromProxy hostCfg;
      isHttpsTarget = target != null && lib.hasPrefix "https://" target;
      # Use per-service override if set, otherwise fall back to global default
      difficulty =
        if hostCfg.anubis.difficulty != null then hostCfg.anubis.difficulty else cfg.defaultDifficulty;
      ogPassthrough =
        if hostCfg.anubis.ogPassthrough != null then
          hostCfg.anubis.ogPassthrough
        else
          cfg.defaultOgPassthrough;
      # Socket paths must use the new format: /run/anubis/anubis-<name>/
      socketDir = "/run/anubis/anubis-${instanceName}";
    in
    {
      enable = true;
      settings = {
        TARGET = target;
        # Use new socket path format (required when multiple instances exist)
        BIND = "${socketDir}/anubis.sock";
        METRICS_BIND = "${socketDir}/anubis-metrics.sock";
        DIFFICULTY = difficulty;
        OG_PASSTHROUGH = ogPassthrough;
        SERVE_ROBOTS_TXT = cfg.defaultServeRobotsTxt;
        COOKIE_PARTITIONED = true;
        COOKIE_SECURE = true;
        COOKIE_SAME_SITE = "Lax";
        # Skip TLS verification for self-signed certs on internal backends
        TARGET_INSECURE_SKIP_VERIFY = isHttpsTarget;
      }
      // lib.optionalAttrs (cfg.cookieDomain != null) { COOKIE_DOMAIN = cfg.cookieDomain; }
      // lib.optionalAttrs (cfg.webmasterEmail != null) { WEBMASTER_EMAIL = cfg.webmasterEmail; };
      botPolicy = cfg.botPolicy;
    };
in
{
  options.codgician.services.anubis = {
    enable = lib.mkEnableOption "Anubis bot protection";

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
        The domain for Anubis challenge cookies. Set this to your base domain
        (e.g., "codgician.me") to share challenge passes across subdomains.
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
        Global bot policy configuration. Set to null to use Anubis built-in defaults.
        See https://anubis.techaro.lol/docs/admin/policies for details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Add nginx user to anubis group for Unix socket access
    users.users.nginx.extraGroups = [ "anubis" ];

    # Configure upstream Anubis module
    services.anubis = {
      defaultOptions = {
        settings = {
          DIFFICULTY = cfg.defaultDifficulty;
          OG_PASSTHROUGH = cfg.defaultOgPassthrough;
          SERVE_ROBOTS_TXT = cfg.defaultServeRobotsTxt;
        }
        // lib.optionalAttrs (cfg.webmasterEmail != null) { WEBMASTER_EMAIL = cfg.webmasterEmail; };
        botPolicy = cfg.botPolicy;
      };

      # Generate instances from enabled reverse proxies
      instances = lib.mapAttrs' (
        name: hostCfg: lib.nameValuePair (sanitizeName name) (mkAnubisInstance name hostCfg)
      ) anubisEnabledProxies;
    };

    # Configure agenix secret for signing key (enables cross-subdomain cookie sharing)
    codgician.system.agenix.secrets.anubis-private-key.owner = "anubis";

    # Add EnvironmentFile to all Anubis instances for the signing key
    systemd.services = lib.mapAttrs' (
      name: _:
      lib.nameValuePair "anubis-${sanitizeName name}" {
        serviceConfig.EnvironmentFile = [ ageCfg.anubis-private-key.path ];
      }
    ) anubisEnabledProxies;

    # Assertions
    assertions = lib.mapAttrsToList (name: hostCfg: {
      assertion = !hostCfg.anubis.enable || (getTargetFromProxy hostCfg) != null;
      message = ''
        anubis: Reverse proxy "${name}" has anubis.enable = true but no proxyPass configured
        in locations."/".passthru. Anubis needs a target to protect.
      '';
    }) nginxCfg.reverseProxies;
  };
}
