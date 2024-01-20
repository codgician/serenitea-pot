{ config, osConfig, lib, pkgs, ... }: {

  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
      ] ++ lib.optionals pkgs.stdenvNoCC.isDarwin [
        "macos"
      ];
      theme = "half-life";
    };

    initExtra = ''
      zstyle :omz:plugins:ssh-agent quiet yes
    '' + lib.optionalString pkgs.stdenvNoCC.isDarwin (
      lib.optionalString osConfig.homebrew.enable ''
        eval "$(/opt/homebrew/bin/brew shellenv)"
      ''
    );
  };

  # Also enable direnv
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
}
