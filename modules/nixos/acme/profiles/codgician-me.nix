{
  domain,
  config,
  lib,
  ...
}:
{
  security.acme.certs."${domain}" = {
    email = "codgician@outlook.com";
    environmentFile = config.codgician.secrets.files.cloudflare-credential.path;
    dnsProvider = "cloudflare";
    group = with config.services.nginx; lib.mkIf enable user;
  };

}
