{ config, lib, pkgs, agenix, ... }: {

  # My settings
  codgician = {
    services = {
      nixos-vscode-server.enable = true;

      nginx = {
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
            locations."/".proxyPass = "https://192.168.0.6";
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

      wireguard = {
        enable = true;
        interfaces.wg0 = {
          host = "lumine";
          peers = [ "suzhou" ];
          allowedIPsAsRoutes = true;
        };
      };
    };

    system = {
      agenix.enable = true;
      auto-upgrade.enable = true;
      common.enable = true;
    };

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = secretsDir + "/codgiHashedPassword.age";
      extraGroups = [ "wheel" ];
    };
  };

  # Home manager
  home-manager.users.codgi = { config, ... }: rec {
    codgician.codgi = {
      git.enable = true;
      pwsh.enable = true;
      ssh.enable = true;
      zsh.enable = true;
    };

    home.stateVersion = "24.05";
    home.packages = with pkgs; [ httplz iperf3 screen ];
  };

  networking.useNetworkd = true;
  services.resolved.enable = true;

  # Use the systemd-boot EFI boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Global packages
  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];

  # Enable zram swap
  zramSwap.enable = true;

  # Firewall
  networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
