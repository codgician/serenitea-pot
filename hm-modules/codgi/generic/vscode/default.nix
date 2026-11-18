{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.vscode;
  fontFamily = "'Cascadia Code NF', 'Cascadia Code', 'monospace'";
  fontSize = 14;
in
{
  options.codgician.codgi.vscode.enable = lib.mkEnableOption "Visual Studio Code";

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      mutableExtensionsDir = false;

      profiles.default = {
        enableUpdateCheck = false;
        enableExtensionUpdateCheck = false;

        extensions =
          with pkgs.vscode-marketplace;
          [
            editorconfig.editorconfig
            tamasfe.even-better-toml
            ms-vscode.hexeditor
            ms-vscode.vscode-copilot-vision
            ms-vscode.vscode-diagnostic-tools
            ms-vscode.remote-explorer
            ms-vscode.remote-repositories
            ms-vscode.azure-repos
            github.remotehub
            ms-vscode.remote-server
            ms-vscode-remote.remote-ssh-edit
            ms-vscode-remote.remote-containers
            dnicolson.binary-plist
            mkhl.direnv
          ]
          ++ (with pkgs.vscode-marketplace-release; [
            github.copilot-chat
            github.vscode-pull-request-github
            ms-vscode-remote.remote-ssh
          ]);

        userSettings = {
          chat = {
            agent.enabled = true;
            editor = {
              inherit fontFamily;
              fontSize = 12; # not using the same size as editor
            };
            edits2.enabled = true;
            emptyState.history.enabled = true;
            mcp = {
              assisted.nuget.enabled = true;
              gallery.enabled = true;
            };
          };
          editor = { inherit fontFamily fontSize; };
          terminal.integrated = { inherit fontFamily fontSize; };
          remote.SSH = {
            defaultExtensions = builtins.map (
              ext: ext.vscodeExtUniqueId
            ) config.programs.vscode.profiles.default.extensions;
          };
          github.copilot = {
            nextEditSuggestions.enabled = true;
            chat = {
              agent.thinkingTool = true;
              codesearch.enabled = true;
              followUps = "always";
              edits.temporalContext.enabled = true;
              editor.temporalContext.enabled = true;
              executePrompt.enabled = true;
              temporalContext.enabled = true;
              scopeSelection = true;
              nextEditSuggestions = {
                enabled = true;
                fixes = true;
              };
              generateTests.codeLens = true;
              languageContext = {
                fix.typescript.enabled = true;
                inline.typescript.enabled = true;
                typescript.includeDocumentation = true;
              };
              newWorkspace.useContext7 = true;
              notebook = {
                enhancedNextEditSuggestions.enabled = true;
                followCellExecution.enabled = true;
              };
              search = {
                semanticTextResults = true;
                keywordSuggestions = true;
              };
            };
          };
          git = {
            allowForcePush = true;
          };
        };
      };
    };
  };
}
