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

    home = {
      packages = with pkgs; [
        (dotnetCorePackages.combinePackages (
          with dotnetCorePackages;
          [
            sdk_8_0
            sdk_9_0
            sdk_10_0
          ]
        ))
        omnisharp-roslyn
      ];

      # Azure Artifacts credential provider - symlink to NuGet plugin discovery path
      file.".nuget/plugins/netcore/CredentialProvider.Microsoft".source =
        "${pkgs.azure-artifacts-credprovider}/lib/azure-artifacts-credprovider";

      sessionPath = [ "$HOME/.dotnet/tools" ];
      sessionVariables.NUGET_PACKAGES = "$HOME/.nuget/packages";
    };
  };
}
