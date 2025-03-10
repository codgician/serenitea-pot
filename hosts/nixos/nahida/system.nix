{ lib, pkgs, ... }:
{
  # My settings
  codgician = {
    containers.comfyui = {
      enable = true;
      dataDir = "/nix/persist/comfyui";
      reverseProxy = {
        enable = true;
        domains = [ "vanarana.codgician.me" ];
      };
    };

    services = {
      ollama = {
        enable = true;
        acceleration = "cuda";
        loadModels = [
          "deepseek-r1:32b"
          "openthinker:32b"
          "qwq:32b"
          "llama3.2-vision:11b"
          "phi4:14b"
        ];
      };

      litellm.enable = true;
      open-webui = {
        enable = true;
        reverseProxy = {
          enable = true;
          domains = [ "akasha.codgician.me" ];
        };
      };

      jellyfin = {
        enable = true;
        reverseProxy = {
          enable = true;
          domains = [ "fin.codgician.me" ];
        };
      };

      jupyter = {
        enable = true;
        notebookDir = "/mnt/media/jupyter";
        reverseProxy = {
          enable = true;
          domains = [ "aranyaka.codgician.me" ];
        };
      };

      nixos-vscode-server.enable = true;
      nginx.openFirewall = true;
    };

    system = {
      auto-upgrade.enable = true;
      impermanence.enable = true;
      secure-boot.enable = true;
      nix.useCnMirror = true;
    };

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = secretsDir + "/codgiHashedPassword.age";
      extraGroups = [
        "wheel"
        "podman"
      ];
    };

    virtualization.podman.enable = true;
  };

  # Home manager
  home-manager.users.codgi =
    { ... }:
    {
      codgician.codgi = {
        dev = {
          haskell.enable = true;
          nix.enable = true;
          rust.enable = true;
        };

        git.enable = true;
        pwsh.enable = true;
        ssh.enable = true;
        zsh.enable = true;
      };

      home.stateVersion = "24.11";
      home.packages = with pkgs; [
        httplz
        screen
        nur.repos.codgician.gddr6
      ];
    };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/nix/persist".neededForBoot = true;

  # Global packages
  environment.systemPackages = [ ];

  # Use networkd
  networking.useNetworkd = true;

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
  system.stateVersion = "24.11"; # Did you read the comment?
}
