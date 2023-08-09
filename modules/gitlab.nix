{ config, lib, pkgs, ... }: {
  config = {
    services.gitlab = {
      enable = true;
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
      packages.gitlab = pkgs.gitlab;
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
      builtins.foldl' (x: y: x // y) { } (map (nameToObj) [ "gitlabInitRootPasswd" "gitlabDb" "gitlabJws" "gitlabOtp" "gitlabSecret" ]);

    # Ngnix configurations
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts."git.codgician.me" = {
        locations."/".proxyPass = "http://unix:/run/gitlab/gitlab-workhorse.socket";
        forceSSL = true;
        http2 = true;
        enableACME = true;
        acmeRoot = null;
      };
    };

    # SSL certificate
    security.acme.certs."git.codgician.me" = {
      domain = "git.codgician.me";
      extraDomainNames = [
        "sz.codgician.me"
        "sz4.codgician.me"
        "sz6.codgician.me"
      ];
      group = config.services.nginx.user;
    };
  };
}
