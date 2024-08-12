{ config, lib, pkgs, agenix, ... }: {

  # My settings
  codgician = {
    services = {
      comfyui = {
        enable = false;
        dataDir = "/nix/persist/comfyui";
        reverseProxy = {
          enable = true;
          domains = [ "comfy.codgician.me" ];
        };
      };

      jellyfin = {
        enable = true;
        reverseProxy = {
          enable = true;
          domains = [ "fin.codgician.me" ];
        };
      };

      nixos-vscode-server.enable = true;
      nginx.openFirewall = true;
    };

    system = {
      auto-upgrade.enable = true;
      impermanence.enable = true;
      secure-boot.enable = true;
    };

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = secretsDir + "/codgiHashedPassword.age";
      extraGroups = [ "wheel" "podman" ];
    };

    virtualization.podman.enable = true;
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

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Global packages
  environment.systemPackages = with pkgs; [ ];

  # Firewall
  networking.firewall.enable = true;

  # Enable zram swap
  zramSwap.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
