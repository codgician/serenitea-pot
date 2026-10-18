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
    let
      sharedOptions =
        (import ../modules/nixos/services/nginx/reverse-proxy-options.nix {
          inherit
            lib
            serviceName
            defaultDomains
            defaultDomainsText
            ;
        }).options;
    in
    sharedOptions
    // {
      # Evaluate location definitions only in the nginx consumer. Otherwise the
      # source submodule's defaults would override inherited root ACL settings.
      locations = sharedOptions.locations // {
        type = types.attrsOf types.deferredModule;
        description = sharedOptions.locations.description + ''
          Locations inherit this service's LAN-only and Authelia settings unless
          explicitly overridden. Root location settings override the generated
          proxy defaults.
        '';
      };

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
      rootLocation ? "/",
      extraVhostConfig ? { },
    }:
    lib.mkIf cfg.reverseProxy.enable {
      enable = true;
      reverseProxies.${serviceName} = lib.mkMerge [
        {
          inherit (cfg.reverseProxy)
            enable
            https
            authelia
            domains
            anubis
            robots
            ;
          locations = lib.mkMerge [
            {
              ${rootLocation} = {
                lanOnly = lib.mkDefault cfg.reverseProxy.lanOnly;
                authelia.enable = lib.mkDefault cfg.reverseProxy.authelia.enable;
                passthru.proxyPass = lib.mkDefault cfg.reverseProxy.proxyPass;
              };
            }
            (lib.mapAttrs (_: location: _: {
              imports = [ location ];
              config = {
                lanOnly = lib.mkDefault cfg.reverseProxy.lanOnly;
                authelia.enable = lib.mkDefault cfg.reverseProxy.authelia.enable;
              };
            }) cfg.reverseProxy.locations)
          ];
        }
        extraVhostConfig
      ];
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
