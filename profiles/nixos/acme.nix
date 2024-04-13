# DEPRECATED: This file will be removed when all files are migrated to nix module

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
  };
}
