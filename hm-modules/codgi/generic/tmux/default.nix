{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.codgician.codgi.tmux;
in
{
  options.codgician.codgi.tmux.enable = lib.mkEnableOption "tmux";

  config = lib.mkIf cfg.enable {
    programs.tmux = {
      enable = true;
      secureSocket = true;
      extraConfig = ''
        set -g set-clipboard on
        set -g allow-passthrough all
      '';
    };

    home.packages = with pkgs; [ xclip ];
  };
}
