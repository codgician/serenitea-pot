{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.dev.haskell;
in
{
  options.codgician.codgi.dev.haskell = {
    enable = lib.mkEnableOption "Haskell dev environment.";
  };

  config = lib.mkIf cfg.enable {
    programs.vscode.profiles.default = {
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
