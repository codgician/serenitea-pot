{ domain, config, lib, pkgs, ... }:
let
  secretsDir = ../../../../secrets;
in
{
  security.acme.certs."${domain}" = {
    email = "codgician@outlook.com";
    credentialsFile = config.age.secrets.cloudflareCredential.path;
    dnsProvider = "cloudflare";
    group = config.services.nginx.user;
  };

  codgician.acme."${domain}".ageSecretFilePath = secretsDir + "/cloudflareCredential.age";
}
