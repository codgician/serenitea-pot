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
    (import ../modules/nixos/services/nginx/reverse-proxy-options.nix {
      inherit
        lib
        serviceName
        defaultDomains
        defaultDomainsText
        ;
    }).options
    // {
      proxyPass = lib.mkOption {
        type = with types; nullOr str;
        default = defaultProxyPass;
        defaultText = lib.mkIf (defaultProxyPass != null) defaultProxyPassText;
        description = "Source URI for the reverse proxy.";
      };

      lanOnly = lib.mkEnableOption ''
        Only allow requests from LAN clients.
      '';
    }
    // extraOptions;

  # Make config for service reverse proxy
  mkServiceReverseProxyConfig =
    {
      serviceName,
      cfg,
      extraVhostConfig ? { },
    }:
    {
      codgician.services.nginx = lib.mkIf cfg.reverseProxy.enable {
        enable = true;
        reverseProxies.${serviceName} = lib.mkMerge [
          {
            inherit (cfg.reverseProxy)
              enable
              https
              authelia
              domains
              ;
            locations."/" = {
              inherit (cfg.reverseProxy) lanOnly;
              authelia.enable = cfg.reverseProxy.authelia.enable;
              passthru = { inherit (cfg.reverseProxy) proxyPass; };
            };
          }
          extraVhostConfig
        ];
      };
    };
}
