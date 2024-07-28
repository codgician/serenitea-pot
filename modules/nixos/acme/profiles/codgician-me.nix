{ domain, config, lib, pkgs, ... }:
let
  credPath = lib.codgician.secretsDir + "/cloudflareCredential.age";
in
{
  security.acme.certs."${domain}" = {
    email = "codgician@outlook.com";
    credentialsFile = config.age.secrets.cloudflareCredential.path;
    dnsProvider = "cloudflare";
    group = config.services.nginx.user;
  };

  codgician.acme."${domain}".ageSecretFilePath = credPath;

  assertions = lib.codgician.mkAgenixAssertions [ credPath ];
}
