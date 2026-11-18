{ pkgs, ... }:
{
  codgician.system = {
    impermanence.enable = false;
    wsl = {
      enable = true;
      defaultUser = "codgi";
      docker-desktop.enable = true;
    };
  };

  home-manager.users.codgi.codgician.codgi = {
    claude-code.enable = true;
    codex.enable = true;
    oh-my-pi.enable = true;
    mcp.enable = true;
  };

  zramSwap.enable = true;

  networking.firewall.enable = false;

  system.stateVersion = "26.05";
}
