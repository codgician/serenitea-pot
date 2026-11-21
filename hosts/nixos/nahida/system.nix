{
  config,
  lib,
  pkgs,
  ...
}:
let
  dshPort = 3080;
in
{
  codgician = {
    services = {
      jupyter = {
        enable = true;
        notebookDir = "/lab/jupyter";
        kernels = {
          ihaskell.enable = true;
          python.enable = true;
        };
      };

      openvscode-server.enable = true;

      nginx = {
        enable = true;
        openFirewall = true;

        # The dsh Web UI is a Home Manager service; its site is in the nginx module.
        reverseProxies.dsh-web = {
          proxyPass = "http://127.0.0.1:${toString dshPort}";
          locations."/".extraConfig = ''
            # dsh's initial URL contains a browser login token.
            access_log off;
            proxy_cookie_flags ~^dsh-auth- secure;
            proxy_buffering off;
          '';
        };
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
      dsh = {
        enable = true;
        web = {
          domain = builtins.head config.codgician.services.nginx.reverseProxies.dsh-web.domains;
          port = dshPort;
        };
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
