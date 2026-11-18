{ lib, ... }:
{
  codgician.users.codgi.enable = true;

  home-manager.users.codgi = {
    codgician.codgi = {
      dev.nix.enable = true;
      git.enable = true;
      pwsh.enable = true;
      ssh.enable = true;
      tmux.enable = true;
      zsh.enable = true;
    };

    home.stateVersion = lib.mkDefault "26.05";
  };
}
