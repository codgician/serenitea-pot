{ config, lib, pkgs, ... }:
let
  domain = "git.codgician.me";
in
{
  config = {
    services.gitlab = rec {
      enable = true;
      packages.gitlab = pkgs.gitlab;

      statePath = "/mnt/gitlab/";
      https = true;
      port = 443;

      initialRootPasswordFile = config.age.secrets.gitlabInitRootPasswd.path;
      secrets = {
        dbFile = config.age.secrets.gitlabDb.path;
        jwsFile = config.age.secrets.gitlabJws.path;
        otpFile = config.age.secrets.gitlabOtp.path;
        secretFile = config.age.secrets.gitlabSecret.path;
      };
      smtp = {
        enable = true;
        enableStartTLSAuto = true;
        tls = false;
        authentication = "login";
        address = "smtp.office365.com";
        port = 587;
        username = "bot@codgician.me";
        passwordFile = config.age.secrets.gitlabSmtp.path;
        domain = "codgician.me";
      };
      extraConfig.gitlab.email_from = smtp.username;
    };

    # PostgreSQL configurations
    services.postgresql = {
      dataDir = "/mnt/postgres/";
      settings = {
        full_page_writes = false; # Not needed for ZFS
      };
    };

    # Protect secrets
    age.secrets =
      let
        secretsDir = builtins.toString ../secrets;
        nameToObj = name: { "${name}" = { file = "${secretsDir}/${name}.age"; owner = config.services.gitlab.user; mode = "600"; }; };
      in
      builtins.foldl' (x: y: x // y) { } (map (nameToObj) [ "gitlabInitRootPasswd" "gitlabDb" "gitlabJws" "gitlabOtp" "gitlabSecret" "gitlabSmtp" ]);

    # Ngnix configurations
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts."${domain}" = {
        locations."/".proxyPass = "http://unix:/run/gitlab/gitlab-workhorse.socket";
        forceSSL = true;
        http2 = true;
        enableACME = true;
        acmeRoot = null;
      };
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
  };
}
