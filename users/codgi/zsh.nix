{ config, osConfig, lib, pkgs, ... }: {

  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "ssh-agent" ] ++ (if pkgs.stdenvNoCC.isDarwin then [ "macos" ] else [ ]);
      theme = "half-life";
    };

    initExtra = lib.mkIf pkgs.stdenvNoCC.isDarwin
      ''
        zstyle :omz:plugins:ssh-agent quiet yes
        zstyle :omz:plugins:ssh-agent ssh-add-args --apple-load-keychain
        ${if osConfig.homebrew.enable then ''eval "$(/opt/homebrew/bin/brew shellenv)"'' else ""}
      '';
  };
}
