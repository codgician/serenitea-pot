{ config, lib, ... }:
{
  codgician = {
    secrets.files.saw-basic-auth.owner = "nginx";

    services = {
      fcitx5.enable = true;
      postgresql.zfsOptimizations = true;
      sing-box.users = [ "codgi" ];

      nginx = {
        landingPage = {
          domain = lib.codgician.inventory.zone;
          footer = "Our paths will surely cross";
        };

        reverseProxies = {
          saw.locations."/".extraConfig = ''
            client_max_body_size 128M;
            proxy_buffering off;
            include ${config.codgician.secrets.files.saw-basic-auth.path};
          '';

          ${lib.codgician.published.services.dsh-web.edgeVhost}.locations."/".extraConfig = ''
            access_log off;
            proxy_buffering off;
          '';
        };
      };
    };
  };

  home-manager.users.codgi.codgician.codgi.github-copilot-cli.enable = true;

  networking.hostId = "2b4cf168";

  # Select internationalisation properties.
  i18n = {
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "zh_CN.UTF-8/UTF-8"
    ];
  };

  system.stateVersion = "26.05";
}
