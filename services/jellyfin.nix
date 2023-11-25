{ config, lib, pkgs, ... }:
let
  domain = "fin.codgician.me";
  dataDir = "/mnt/data/jellyfin";
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

    # Create .pfx for Jellyfin and load new certificate
    postRun = ''
      cat full.pem | ${pkgs.openssl}/bin/openssl pkcs12 -export -passout pass: -out cert.pfx
      chmod --reference=full.pem cert.pfx
      chown --reference=full.pem cert.pfx
      systemctl restart jellyfin
    '';
  };

  # Load certificate for Jellyfin
  systemd.services.jellyfin = {
    requires = [ "acme-finished-${domain}.target" ];
    serviceConfig.LoadCredential =
      let
        certDir = config.security.acme.certs."${domain}".directory;
      in
      [ "cert.pfx:${certDir}/cert.pfx" ];
  };
}
