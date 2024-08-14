{ config, osConfig, lib, pkgs, ... }:
let
  cfg = config.codgician.codgi.dev.haskell;
  types = lib.types;
in
{
  options.codgician.codgi.dev.haskell = {
    enable = lib.mkEnableOption "Enable Haskell dev environment.";
  };

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      extensions = with pkgs.vscode-extensions; [
        haskell.haskell
      ];

      userSettings.haskell.serverExecutablePath =
        "${pkgs.haskell-language-server}/bin/haskell-language-server-wrapper";
    };

    home.packages = with pkgs; [
      ghc
      stack
      cabal-install
      cabal2nix
    ];
  };
}
