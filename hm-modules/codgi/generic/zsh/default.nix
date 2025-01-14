{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.zsh;
in
{
  options.codgician.codgi.zsh.enable = lib.mkEnableOption "Enable zsh user profiles.";

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      oh-my-zsh = {
        enable = true;
        plugins =
          [
            "git"
          ]
          ++ lib.optionals pkgs.stdenvNoCC.isDarwin [
            "macos"
          ];
        theme = "half-life";
      };

      initExtra =
        ''
          zstyle :omz:plugins:ssh-agent quiet yes
        ''
        + lib.optionalString pkgs.stdenvNoCC.isDarwin (
          lib.optionalString osConfig.homebrew.enable ''
            if [ -f /opt/homebrew/bin/brew ]; then 
              eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
          ''
        );
    };

    # Also enable direnv
    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
