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

        # Haskell kernel (Nix-managed)
        extraKernels.ihaskell = {
          enable = true;
          extraPackages =
            ps: with ps; [
              # Core utilities (note: text, bytestring, containers, mtl, transformers, time
              # are GHC core libraries - already included, don't need to be specified)
              lens
              lens-aeson
              aeson
              vector

              # Data visualization
              ihaskell-hvega
              hvega
              diagrams
              diagrams-cairo
              diagrams-svg

              # Web & HTTP
              wreq
              http-client
              http-client-tls

              # Scientific computing
              statistics
              scientific

              # Utilities
              unordered-containers
              hashable
              uuid
            ];
        };

        # Python kernel (lazy pip-based for agile experimentation)
        extraKernels.python-lazy = {
          enable = true;
          # Default packages installed on first kernel launch
          # Add more via !pip install in notebooks
          defaultPackages = [
            "numpy"
            "pandas"
            "matplotlib"
            "scipy"
            "scikit-learn"
            "torch"
            "transformers"
          ];
        };

        reverseProxy = {
          enable = true;
          domains = [ "dragonspine.codgician.me" ];
          authelia.enable = true;
        };
      };

      nginx = {
        enable = true;
        openFirewall = true;
        reverseProxies.opencode-web = {
          enable = true;
          domains = [ "fragments.codgician.me" ];
          authelia = {
            enable = true;
            rules = [
              {
                users = [ "codgi" ];
                policy = "two_factor";
              }
            ];
          };
          locations."/".passthru.proxyPass = "http://127.0.0.1:3030";
        };
      };
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
        opencode = {
          enable = true;
          web.enable = true;
        };
        pwsh.enable = true;
        ssh.enable = true;
        zsh.enable = true;
      };

      home.stateVersion = "25.11";
      home.packages = with pkgs; [
        screen
        tmux
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
