{ domain, config, lib, pkgs, ... }:
let
  secretsDir = ../../../../secrets;
in
{
  security.acme.certs."${domain}" = {
    email = "codgician@outlook.com";
    credentialsFile = config.age.secrets.cloudflareCredential.path;
    dnsProvider = "cloudflare";
    keyType = "ec384";
    extraLegoFlags = [ "--dns-timeout" "600" ];
    group = config.services.nginx.user;
  };

  codgician.acme."${domain}".ageSecretFilePath = secretsDir + "/cloudflareCredential.age";
}
