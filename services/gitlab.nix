{ config, pkgs, ... }:
let
  domain = "git.codgician.me";
in
{
  config = {
    services.gitlab = rec {
      enable = true;
      packages.gitlab = pkgs.gitlab;
      statePath = "/mnt/gitlab/";
      host = domain;
      https = true;
      port = 443;
      user = "gitlab";

      # Secrets
      initialRootPasswordFile = config.age.secrets.gitlabInitRootPasswd.path;
      secrets = {
        dbFile = config.age.secrets.gitlabDb.path;
        jwsFile = config.age.secrets.gitlabJws.path;
        otpFile = config.age.secrets.gitlabOtp.path;
        secretFile = config.age.secrets.gitlabSecret.path;
      };

      # Mail settings
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
      extraConfig.gitlab = {
        email_from = smtp.username;
        email_reply_to = smtp.username;
      };

      # OmniAuth
      extraConfig.omniauth = {
        enabled = true;
        allow_single_sign_on = [ "github" ];
        block_auto_created_users = true;
        providers = [
          {
            name = "github";
            label = "GitHub";
            app_id = "3bc605d269d8117af816";
            app_secret = { _secret = config.age.secrets.gitlabOmniAuthGitHub.path; };
            args = {
              scope = "user:email";
            };
          }
        ];
      };
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
      builtins.foldl' (x: y: x // y) { } (map (nameToObj) [
        "gitlabInitRootPasswd"
        "gitlabDb"
        "gitlabJws"
        "gitlabOtp"
        "gitlabSecret"
        "gitlabSmtp"
        "gitlabOmniAuthGitHub"
      ]);

    # Ngnix configurations
    services.nginx.virtualHosts."${domain}" = {
      locations."/" = {
        proxyPass = "http://unix:/run/gitlab/gitlab-workhorse.socket";
        proxyWebsockets = true;
        recommendedProxySettings = true;
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
    };
  };
}
