{
  config,
  lib,
  pkgs,
  ...
}:
{
  codgician = {
    secrets.files.saw-basic-auth.owner = "nginx";

    services = {
      fcitx5.enable = true;
      postgresql.zfsOptimizations = true;
      sing-box.users = [ "codgi" ];

      nginx.reverseProxies = {
        saw.locations."/".extraConfig = ''
          client_max_body_size 128M;
          proxy_buffering off;
          include ${config.codgician.secrets.files.saw-basic-auth.path};
        '';

        ${lib.codgician.published.services.dsh-web.edgeVhost}.locations."/".extraConfig = ''
          access_log off;
          proxy_buffering off;
        '';

        # Everything in the zone without a vhost of its own.
        ${lib.codgician.inventory.zone} = {
          enable = true;
          domains = with lib.codgician.inventory; [
            zone
            "*.${zone}"
          ];
          locations."/".root = import ../../roles/edge/landing-page.nix {
            inherit pkgs;
            name = "lumine";
            message = "Our paths will surely cross";
          };
        };
      };
    };
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
