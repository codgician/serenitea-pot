{
  domain,
  config,
  lib,
  ...
}:
let
  credPath = with lib.codgician; getAgeSecretPathFromName "cloudflare-credential";
in
{
  security.acme.certs."${domain}" = {
    email = "codgician@outlook.com";
    credentialsFile = config.age.secrets.cloudflare-credential.path;
    dnsProvider = "cloudflare";
    group = config.services.nginx.user;
  };

  codgician.acme."${domain}".ageSecretFilePath = credPath;

  assertions = lib.codgician.mkAgenixAssertions [ credPath ];
}
