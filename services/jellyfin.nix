{ config, lib, pkgs, ... }:
let
  domain = "fin.codgician.me";
in
{
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    user = "jellyfin";
  };

  # Ngnix configurations
  services.nginx.virtualHosts."${domain}" = {
    locations."/".proxyPass = "http://localhost:8096";
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

    # Create .pfx for Jellyfin
    postRun = ''
      cat full.pem | ${pkgs.openssl}/bin/openssl pkcs12 -export -passout pass: -out cert.pfx
      chmod --reference=full.pem cert.pfx
      chown --reference=full.pem cert.pfx
    '';
  };

  # Load certificate for Jellyfin
  systemd.services.jellyfin = {
    requires = [ "acme-finished-${domain}.target" ];
    serviceConfig.LoadCredential = [ "cert.pfx:/var/lib/acme/${domain}/cert.pfx" ];
  };

  # Persist jellyfin data directories
  environment.persistence."/nix/persist/" = {
    directories = [
      "/var/lib/jellyfin"
    ];
  };
}
