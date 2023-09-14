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

    initExtra = lib.optionalString osConfig.homebrew.enable ''
      eval "$(/opt/homebrew/bin/brew shellenv)"
    '';
  };
}
