{
  domain,
  config,
  lib,
  ...
}:
let
  credPath = with lib.codgician; getAgeSecretPathFromName "tencent-dns-credential";
in
{
  security.acme.certs."${domain}" = {
    email = "codgician@outlook.com";
    environmentFile = config.codgician.secrets.files.tencent-dns-credential.path;
    dnsProvider = "tencentcloud";
    group = with config.services.nginx; lib.mkIf enable user;
  };

  codgician.acme."${domain}".ageSecretFilePath = credPath;
}
