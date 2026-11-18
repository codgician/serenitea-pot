{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.codgician.services.meshcentral;
  inherit (lib.codgician) published;
  svc = published.services.meshcentral;
in
{
  options.codgician.services.meshcentral.enable =
    lib.codgician.mkPublishedEnableOption config "meshcentral";

  config = lib.mkMerge [
    # Meshcentral configurations
    (lib.mkIf cfg.enable {
      codgician.services.nginx.reverseProxies.meshcentral.proxyPass = svc.localUpstream;

      services.meshcentral = {
        enable = true;
        settings = {
          domains."" = {
            showPasswordLogin = false;
            allowedOrigin = [ svc.domain ];
            authStrategies.oidc = {
              issuer = published.autheliaUrl;
              client =
                let
                  url = "https://${svc.domain}";
                in
                {
                  client_id = "meshcentral";
                  client_secret._secret = config.codgician.secrets.files.meshcentral-oidc-secret-authelia-main.path;
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
            PortBind = "127.0.0.1";
            Port = svc.port;
            TlsOffload = "127.0.0.1,::1";
          };
        };
      };

      # Make meshcentral config module support secrets
      systemd.services.meshcentral = {
        serviceConfig = {
          ExecStartPre = "+${pkgs.writeShellScript "meshcentral-pre-start" (utils.genJqSecretsReplacementSnippet config.services.meshcentral.settings "/run/meshcentral/config.json")}";
          ExecStart = lib.mkForce "${pkgs.meshcentral}/bin/meshcentral --datapath /var/lib/meshcentral --configfile /run/meshcentral/config.json";
          RuntimeDirectory = "meshcentral";
          RuntimeDirectoryMode = "0700";
        };
      };
    })

    (lib.mkIf (cfg.enable || published.fronts config.networking.hostName "meshcentral") {
      codgician.services.nginx.reverseProxies.meshcentral.locations."/".extraConfig = ''
        proxy_buffering off;
      '';
    })
  ];
}
