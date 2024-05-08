{ domain, config, lib, pkgs, ... }:
let
  credPath = ../../../../secrets/cloudflareCredential.age;
in
{
  security.acme.certs."${domain}" = {
    email = "codgician@outlook.com";
    credentialsFile = config.age.secrets.cloudflareCredential.path;
    dnsProvider = "cloudflare";
    group = config.services.nginx.user;
  };

  codgician.acme."${domain}".ageSecretFilePath = credPath;

  assertions = [
    {
      assertion = config.codgician.system.agenix.enable;
      message = "Agenix must be enabled to acticate codgician-me acme profile.";
    }
  ] ++ lib.codgician.mkAgenixAssertions [ credPath ];
}
