{ config, lib, pkgs, ... }:
let
  domain = "books.codgician.me";
  port = 22542;
in
{
  services.calibre-web = {
    enable = true;
    listen = {
      inherit port;
      ip = "::1";
    };
    openFirewall = false;
    options = {
      enableKepubify = true;
      enableBookConversion = true;
      calibreLibrary = "/mnt/nas/media/books";
    };
  };

  # Ngnix configurations
  services.nginx.virtualHosts."${domain}" = {
    locations."/" = {
      proxyPass = "http://localhost:${builtins.toString port}";
      proxyWebsockets = true;
    };

    # Don't include me in search results
    locations."/robots.txt".return = "200 'User-agent:*\\nDisallow:*'";

    forceSSL = true;
    http2 = true;
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

  # Persist data
  environment.persistence."/nix/persist".directories = [ "/var/lib/calibre-web" ];
}
