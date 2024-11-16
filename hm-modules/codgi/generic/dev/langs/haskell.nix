{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.codgi.dev.haskell;
in
{
  options.codgician.codgi.dev.haskell = {
    enable = lib.mkEnableOption "Enable Haskell dev environment.";
  };

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      extensions = with pkgs.vscode-marketplace; [
        haskell.haskell
        justusadam.language-haskell
      ];

      userSettings.haskell.serverExecutablePath = "haskell-language-server-wrapper";
    };

    home.packages = with pkgs; [
      ghc
      stack
      cabal-install
      haskell-language-server
    ];
  };
}
