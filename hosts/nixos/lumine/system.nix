{ pkgs, ... }:
{
  codgician.services = {
    fcitx5.enable = true;
    litellm = {
      enable = true;
      backend = "container";
      adminUi = {
        enable = true;
        authelia.enable = true;
      };
      reverseProxy = {
        enable = true;
        domains = [ "dendro.codgician.me" ];
        favicon =
          (pkgs.fetchurl {
            url = "https://media.githubusercontent.com/media/codgician/assets/f541d8f18215690ed7b7bbc3b97aa54c6ef2f51e/images/dendro/logo.png";
            sha256 = "sha256-XSikOX3CM4VvwzWkRsETYBLha2VgUHh5m/uxTzm2UQI=";
          }).outPath;
      };
    };

    postgresql.zfsOptimizations = true;
    sing-box.users = [ "codgi" ];
  };

  home-manager.users.codgi.codgician.codgi.github-copilot-cli.enable = true;

  networking.hostId = "2b4cf168";

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "zh_CN.UTF-8/UTF-8"
    ];
  };

  system.stateVersion = "26.05";
}
