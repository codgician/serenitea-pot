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
      trusted_servers = [
        "matrix.org"
      ];
      database_backend = "rocksdb";
      allow_registration = true;
      allow_federation = true;
      allow_encryption = true;
      address = "::1";
    };
  };

  # Ngnix configurations
  services.nginx.virtualHosts."${domain}" = {
    listen = [
      {
        addr = "*";
        port = 443;
      }
      {
        addr = "*";
        port = 8448;
      }
    ];
    
    locations."/" = {
      proxyPass = "http://[::1]:${builtins.toString port}";
      proxyWebsockets = true;
      recommendedProxySettings = false;
    };

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