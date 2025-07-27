{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  serviceName = "meshcentral";
  cfg = config.codgician.services.meshcentral;
  types = lib.types;
in
{
  options.codgician.services.meshcentral = {
    enable = lib.mkEnableOption "meshcentral";

    package = lib.mkPackageOption pkgs "meshcentral" { };

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Host for meshcentral to listen on.
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 3001;
      description = "TCP port for meshcentral to listen.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://${cfg.host}:${toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.services.meshcentral; http://$\{host}:$\{toString port}'';
    };
  };

  config = lib.mkMerge [
    # Meshcentral configurations
    (lib.mkIf cfg.enable {
      services.meshcentral = {
        enable = true;
        settings = {
          domains."" = {
            allowedOrigin = lib.mkIf cfg.reverseProxy.enable cfg.reverseProxy.domains;
            authStrategies.oidc = lib.mkIf cfg.reverseProxy.enable {
              issuer = "https://auth.codgician.me";
              client =
                let
                  scheme = if cfg.reverseProxy.https then "https" else "http";
                  url = "${scheme}://${builtins.head cfg.reverseProxy.domains}";
                in
                {
                  client_id = "meshcentral";
                  client_secret._secret = config.age.secrets.meshcentral-oidc-secret-authelia-main.path;
                  redirect_uri = "${url}/auth-oidc-callback";
                  post_logout_redirect_uri = "${url}/login";
                  token_endpoint_auth_method = "client_secret_post";
                };
              groups = {
                recursive = true;
                required = [
                  "meshcentral-admins"
                  "meshcentral-users"
                ];
                siteadmin = [ "meshcentral-admins" ];
                revokeAdmin = true;
                sync.filter = [
                  "meshcentral-users"
                  "meshcentral-admins"
                ];
                claim = "groups";
              };
              newAccounts = true;
            };
          };
          settings = {
            PortBind = cfg.host;
            Port = cfg.port;
            TlsOffload = "127.0.0.1,::1";
          };
        };
      };

      # Make meshcentral config module support secrets
      systemd.services.meshcentral = {
        preStart = utils.genJqSecretsReplacementSnippet config.services.meshcentral.settings "/run/meshcentral/config.json";
        serviceConfig = {
          DynamicUser = lib.mkForce false;
          ExecStart = lib.mkForce "${cfg.package}/bin/meshcentral --datapath /var/lib/meshcentral --configfile /run/meshcentral/config.json";
          RuntimeDirectory = "meshcentral";
          RuntimeDirectoryMode = "0700";
        };
      };
    })

    # Reverse proxy profiles
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
      extraVhostConfig.locations."/" = {
        inherit (cfg.reverseProxy) lanOnly;
        authelia.enable = cfg.reverseProxy.authelia.enable;
        passthru = {
          inherit (cfg.reverseProxy) proxyPass;
          extraConfig = ''
            proxy_buffering off;
          '';
        };
      };
    })
  ];
}
