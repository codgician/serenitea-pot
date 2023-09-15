{ config, lib, ... }:
let
  domain = "matrix.codgician.me";
  port = 6167;
in
{
  services.matrix-conduit = {
    enable = true;
    settings.global = {
      server_name = "matrix.codgician.me";
      inherit port;
      trusted_servers = [ "matrix.org" "libera.chat" "nixos.org" "gitter.im" "vector.im" ];
      database_backend = "rocksdb";
      allow_registration = true;
      allow_federation = true;
      allow_encryption = true;
      address = "::1";
    };
  };

  # Ngnix configurations
  services.nginx.virtualHosts."${domain}" =
    let
      server = {
        "m.server" = "${domain}:443";
      };
      client = {
        "m.homeserver"."base_url" = "https://${domain}";
        "org.matrix.msc3575.proxy"."url" = "https://${domain}";
        "m.identity_server"."base_url" = "https://vector.im";
      };
    in
    {
      locations."/".extraConfig = "return 404;";
      locations."/_matrix/" = {
        proxyPass = "http://[::1]:${builtins.toString port}";
        proxyWebsockets = true;
        recommendedProxySettings = true;
        extraConfig = ''
          proxy_buffering off;
        '';
      };

      locations."= /.well-known/matrix/server".extraConfig = ''
        add_header Content-Type application/json;
        return 200 '${builtins.toJSON server}';
      '';

      locations."= /.well-known/matrix/client".extraConfig = ''
        add_header Content-Type application/json;
        add_header Access-Control-Allow-Origin *;
        return 200 '${builtins.toJSON client}';
      '';

      forceSSL = true;
      enableACME = true;
      acmeRoot = null;
    };

  # SSL certificate
  security.acme.certs."${domain}" = {
    inherit domain;
    extraDomainNames = [
      "sz.codgician.me"
      "sz4.codgician.me"
      "sz6.codgician.me"
    ];
    group = config.services.nginx.user;
  };
}
