{ lib, pkgs, ... }:
{
  # My settings
  codgician = {
    services = {
      openvscode-server = {
        enable = true;
        user = "codgi";
        group = "users";
        reverseProxy = {
          enable = true;
          domains = [ "leyline.codgician.me" ];
          authelia = {
            enable = true;
            rules = [
              {
                users = [ "leyline" ];
                policy = "two_factor";
              }
            ];
          };
        };
      };

      jupyter = {
        enable = true;
        notebookDir = "/lab/jupyter";
        user = "codgi";
        extraKernels.ihaskell.enable = true;
        reverseProxy = {
          enable = true;
          domains = [ "dragonspine.codgician.me" ];
          authelia.enable = true;
        };
      };
      nginx.openFirewall = true;
    };

    system = {
      auto-upgrade.enable = true;
      impermanence.enable = true;
      nix.useCnMirror = true;
    };

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = getAgeSecretPathFromName "codgi-hashed-password";
      extraGroups = [ "wheel" ];
    };
  };

  # Home manager
  home-manager.users.codgi =
    { ... }:
    {
      codgician.codgi = {
        dev.nix.enable = true;
        git.enable = true;
        mcp.enable = true;
        opencode.enable = true;
        pwsh.enable = true;
        ssh.enable = true;
        zsh.enable = true;
      };

      home.stateVersion = "25.11";
      home.packages = with pkgs; [
        screen
        claude-code-wrapped
      ];
    };

  # Global packages
  environment.systemPackages = [ ];

  # Use networkd
  networking.useNetworkd = true;

  # Firewall
  networking.firewall.enable = true;

  # Enable nix-ld for lab environment
  programs.nix-ld.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
