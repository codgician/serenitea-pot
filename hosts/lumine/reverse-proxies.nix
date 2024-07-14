{ config, pkgs, ... }: {
  codgician.services.nginx = {
    enable = true;
    reverseProxies = {
      "amt.codgician.me" = {
        enable = true;
        https = true;
        domains = [ "amt.codgician.me" ];
        locations."/".proxyPass = "https://192.168.0.7";
      };

      "books.codgician.me" = {
        enable = true;
        https = true;
        domains = [ "books.codgician.me" ];
        locations."/".proxyPass = "https://192.168.0.7";
      };

      "bubbles.codgician.me" = {
        enable = true;
        https = true;
        domains = [ "bubbles.codgician.me" ];
        locations."/".proxyPass = "http://192.168.0.9:1234";
      };

      "fin.codgician.me" = {
        enable = true;
        https = true;
        domains = [ "fin.codgician.me" ];
        locations."/".proxyPass = "https://192.168.0.8";
      };

      "git.codgician.me" = {
        enable = true;
        https = true;
        domains = [ "git.codgician.me" ];
        locations."/".proxyPass = "https://192.168.0.7";
      };

      "hass.codgician.me" = {
        enable = true;
        https = true;
        domains = [ "hass.codgician.me" ];
        locations."/".proxyPass = "http://192.168.0.6:8123";
      };

      "pve.codgician.me" = {
        enable = true;
        https = true;
        domains = [ "pve.codgician.me" ];
        locations."/".proxyPass = "https://192.168.0.21:8006";
      };

      "matrix.codgician.me" = {
        enable = true;
        https = true;
        domains = [ "matrix.codgician.me" ];
        locations."/".proxyPass = "https://192.168.0.7";
      };

      "saw.codgician.me" = {
        enable = true;
        https = true;
        domains = [ "saw.codgician.me" ];
        locations."/".proxyPass = "https://192.168.0.28";
      };

      "codgician.me" = {
        enable = true;
        https = true;
        default = true;
        domains = [ "codgician.me" "*.codgician.me" ];
        locations."/".root = import ./lumine-web.nix { inherit pkgs; };
      };
    };
  };
}
