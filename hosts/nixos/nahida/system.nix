{
  lib,
  pkgs,
  ...
}:
{
  codgician = {
    services = {
      jupyter = {
        enable = true;
        notebookDir = "/lab/jupyter";
        user = "codgi";

        # Haskell kernel (Nix-managed)
        kernels.ihaskell.default = {
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

        # Python kernel (uv/pip inside an FHS sandbox for agile experimentation).
        # The venv lives on /lab (persistent bind mount) and is provisioned with
        # an uv-managed standalone CPython on first launch, so it behaves like a
        # vanilla pip/uv environment on any other Linux distribution.
        kernels.python.default = {
          enable = true;
          # Default packages installed on first kernel launch.
          # Add more later via !uv pip install in notebooks.
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
      };

      dsh-web = {
        enable = true;
        user = "codgi";
      };

      openvscode-server = {
        enable = true;
        user = "codgi";
        group = "users";
      };

      nginx = {
        enable = true;
        openFirewall = true;
      };

      nixos-vscode-server.enable = true;
    };

    system = {
      auto-upgrade.enable = true;
      common.inChina = true;
      impermanence.enable = true;
    };

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = getAgeSecretPathFromName "codgi-hashed-password";
    };
  };

  home-manager.users.codgi = {
    codgician.codgi = {
      claude-code.enable = true;
      codex = {
        enable = true;
        package = pkgs.codex-wrapped;
      };
      dev = {
        dotnet.enable = true;
        nix.enable = true;
      };
      git.enable = true;
      github-copilot-cli.enable = true;
      mcp.enable = true;
      pi-coding-agent.enable = true;
      oh-my-pi.enable = true;
      pwsh.enable = true;
      ssh.enable = true;
      tmux.enable = true;
      zsh.enable = true;
    };

    home.stateVersion = "26.05";

    home.packages = with pkgs; [
      acpica-tools
      uefitool
      binwalk
    ];
  };

  # Use networkd
  networking.useNetworkd = true;

  # Enable nix-ld for lab environment
  programs.nix-ld.enable = true;

  system.stateVersion = "26.05";
}
