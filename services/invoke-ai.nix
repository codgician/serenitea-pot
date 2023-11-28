# Requires nixified-ai
# https://github.com/nixified-ai/flake/blob/master/projects/invokeai/nixos/default.nix

let
  domain = "diffusion.codgician.me";
  port = 9001;
  user = "invoke-ai";
  group = "invoke-ai";
  root = "/var/lib/invoke-ai";
in
{ config, lib, pkgs, inputs, ... }: {
  services.invokeai = {
    enable = true;
    package = inputs.nixified-ai.packages.${config.nixpkgs.system}.invokeai-nvidia;
    inherit user;
    inherit group;
    settings = {
      host = "127.0.0.1";
      inherit port;
      inherit root;
      precision = "auto";
    };
  };

  # Ngnix configurations
  services.nginx.virtualHosts."${domain}" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString port}";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };

    # Don't include me in search results
    locations."/robots.txt".return = "200 'User-agent:*\\nDisallow:*'";

    forceSSL = true;
    enableACME = true;
    acmeRoot = null;
  };

  # SSL certificate
  security.acme.certs."${domain}" = {
    inherit domain;
    extraDomainNames = [
      "sz.codgician.me"
      "sz4.codgician.me"
      "sz6.codgician.me"
    ];
    group = config.services.nginx.user;
  };

  # Persist data
  environment.persistence."/nix/persist".directories = [ root ];
}