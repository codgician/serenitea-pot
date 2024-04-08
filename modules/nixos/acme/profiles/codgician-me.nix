{ domain, config, lib, pkgs, ... }:
let
  secretsDir = ../../../../secrets;
in
{
  security.acme.certs."${domain}" = {
    email = "codgician@outlook.com";
    credentialsFile = config.age.secrets.cloudflareCredential.path;
    dnsProvider = "cloudflare";
    dnsResolver = "1dot1dot1dot1.cloudflare-dns.com:853";
    keyType = "ec384";
    extraLegoFlags = [ "--dns-timeout" "240" ];
    group = config.services.nginx.user;
  };

  codgician.acme."${domain}".ageSecretFilePath = secretsDir + "/cloudflareCredential.age";
}
