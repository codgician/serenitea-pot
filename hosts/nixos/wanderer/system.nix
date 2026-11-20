{
  codgician = {
    services.nixos-vscode-server.enable = true;

    system = {
      auto-upgrade.enable = true;
      wsl = {
        enable = true;
        docker-desktop.enable = true;
      };
    };

    users.codgi.enable = true;
  };

  home-manager.users.codgi = {
    codgician.codgi = {
      claude-code.enable = true;
      codex.enable = true;
      dev.nix.enable = true;
      git.enable = true;
      oh-my-pi.enable = true;
      mcp.enable = true;
      pwsh.enable = true;
      ssh.enable = true;
      tmux.enable = true;
      zsh.enable = true;
    };

    home.stateVersion = "26.05";
  };

  zramSwap.enable = true;

  networking.firewall.enable = false;

  system.stateVersion = "26.05";
}
