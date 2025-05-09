{ lib, ... }:
let
  inherit (lib) types;
in
{
  # Make options for service reverse proxy
  mkServiceReverseProxyOptions =
    {
      serviceName,
      defaultDomains ? [ ],
      defaultDomainsText ? null,
      defaultProxyPass,
      defaultProxyPassText ? null,
      extraOptions ? { },
    }:
    {
      enable = lib.mkEnableOption "Reverse proxy for ${serviceName}";

      domains = lib.mkOption {
        type = types.listOf types.str;
        example = [
          "example.com"
          "example.org"
        ];
        default = defaultDomains;
        defaultText = lib.mkIf (defaultDomainsText != null) defaultDomainsText;
        description = "List of domains for the reverse proxy.";
      };

      proxyPass = lib.mkOption {
        type = types.str;
        default = defaultProxyPass;
        defaultText = lib.mkIf (defaultProxyPass != null) defaultProxyPassText;
        description = "Source URI for the reverse proxy.";
      };

      lanOnly = lib.mkEnableOption "Only allow requests from LAN clients.";
    }
    // extraOptions;

  # Make config for service reverse proxy
  mkServiceReverseProxyConfig =
    {
      serviceName,
      cfg,
      overrideVhostConfig ? { },
    }:
    {
      codgician.services.nginx = lib.mkIf cfg.reverseProxy.enable {
        enable = true;
        reverseProxies.${serviceName} = {
          inherit (cfg.reverseProxy) enable domains;
          https = true;
          locations."/" = { inherit (cfg.reverseProxy) proxyPass lanOnly; };
        } // overrideVhostConfig;
      };
    };
}
