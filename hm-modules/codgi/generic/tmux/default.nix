{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    secureSocket = true;
    extraConfig = ''
      set -g set-clipboard on
      set -g allow-passthrough all
      set -g extended-keys on
      set -g extended-keys-format csi-u
      set -g mouse on
    '';
  };

  home.packages = with pkgs; [ xclip ];
}
