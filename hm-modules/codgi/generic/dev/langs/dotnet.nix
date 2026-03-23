{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.dev.dotnet;
in
{
  options.codgician.codgi.dev.dotnet = {
    enable = lib.mkEnableOption ".NET dev environment";
  };

  config = lib.mkIf cfg.enable {
    programs.vscode.profiles.default = {
      extensions = with pkgs.vscode-marketplace; [
        ms-dotnettools.csharp
        # ms-dotnettools.csdevkit
        ms-dotnettools.vscode-dotnet-runtime
      ];

      userSettings = {
        "[csharp]".editor.tabSize = 4;
        dotnet.server.path = "dotnet";
      };
    };

    home.packages = [
      (pkgs.dotnetCorePackages.combinePackages (
        with pkgs.dotnetCorePackages;
        [
          sdk_8_0
          sdk_9_0
          sdk_10_0
        ]
      ))
      pkgs.omnisharp-roslyn
    ];
  };
}
