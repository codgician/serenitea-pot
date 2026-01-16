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

      anubis = {
        enable = lib.mkEnableOption ''
          Anubis bot protection for ${serviceName}.
        '';

        difficulty = lib.mkOption {
          type = with types; nullOr (ints.between 1 7);
          default = null;
          example = 4;
          description = ''
            Override the global Anubis difficulty for this service.
            Higher values require more proof-of-work from clients.
            Set to null to use the global default.
          '';
        };

        ogPassthrough = lib.mkOption {
          type = with types; nullOr bool;
          default = null;
          example = true;
          description = ''
            Override Open Graph passthrough for this service.
            When enabled, social media preview bots can access content without challenges.
            Set to null to use the global default.
          '';
        };
      };
    }
    // extraOptions;

  # Make config for service reverse proxy
  mkServiceReverseProxyConfig =
    {
      serviceName,
      cfg,
      rootLocation ? "/",
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
              anubis
              ;
            locations.${rootLocation} = {
              inherit (cfg.reverseProxy) lanOnly;
              authelia.enable = cfg.reverseProxy.authelia.enable;
              passthru = { inherit (cfg.reverseProxy) proxyPass; };
            };
          }
          extraVhostConfig
        ];
      };
    };

  # Make a nginx location for hosting static files
  mkNginxLocationForStaticFile = path: {
    root = builtins.dirOf path;
    tryFiles = "/${builtins.baseNameOf path} =404";
    extraConfig = ''
      access_log off; 
      log_not_found off;
    '';
  };
}
