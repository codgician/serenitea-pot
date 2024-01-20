{ config, lib, pkgs, ... }:
let
  domain = "fin.codgician.me";
  user = "jellyfin";
  group = "jellyfin";
in
{
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    inherit user;
    inherit group;
  };

  # Ngnix configurations
  services.nginx.virtualHosts."${domain}" = {
    locations."/" = {
      proxyPass = "http://localhost:8096";
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
  environment.persistence."/nix/persist".directories = [ "/var/lib/jellyfin" ];
}
