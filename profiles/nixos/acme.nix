{ config, pkgs, ... }: {

  config = {
    # ACME configurations
    security.acme = {
      acceptTerms = true;
      defaults = {
        email = "codgician@outlook.com";
        credentialsFile = config.age.secrets.cloudflareCredential.path;
        dnsProvider = "cloudflare";
      };
    };

    # Protect secrets
    age.secrets =
      let
        secretsDir = builtins.toString ../../secrets;
        nameToObj = name: {
          "${name}" = {
            file = "${secretsDir}/${name}.age";
            owner = "root";
            mode = "600";
          };
        };
      in
      builtins.foldl' (x: y: x // y) { } (map (nameToObj) [ "cloudflareCredential" ]);
  };
}
