{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.vscode;
  inherit (lib) types;
in
{
  options.codgician.codgi.vscode = {
    enable = lib.mkEnableOption "Visual Studio Code";

    immutableExtensions = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Make extensions immutable.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      mutableExtensionsDir = !cfg.immutableExtensions;

      profiles.default = {
        enableUpdateCheck = false;
        enableExtensionUpdateCheck = !cfg.immutableExtensions;

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
            github.copilot
            github.copilot-chat
            github.vscode-pull-request-github
            ms-vscode-remote.remote-ssh
          ]);

        userSettings = {
          editor = {
            fontFamily = "'Cascadia Code NF', 'Cascadia Code', monospace";
            fontSize = 14;
          };
          terminal.integrated = {
            fontFamily = "'Cascadia Mono PL', 'Cascadia Mono', monospace";
            fontSize = 14;
          };
          remote.SSH.defaultExtensions = builtins.map (
            ext: ext.vscodeExtUniqueId
          ) config.programs.vscode.profiles.default.extensions;
          "github.copilot.chat.editor.temporalContext.enabled" = true;
          github.copilot = {
            nextEditSuggestions.enabled = true;
            chat = {
              agent.thinkingTool = true;
              codesearch.enabled = true;
              followUps = "always";
              edits.temporalContext.enabled = true;
              temporalContext.enabled = true;
              scopeSelection = true;
              nextEditSuggestions = {
                enabled = true;
                fixes = true;
              };
              generateTests.codeLens = true;
              languageContext.typescript = {
                enabled = true;
                fix.typescript.enabled = true;
                inline.typescript.enabled = true;
              };
              search = {
                semanticTextResults = true;
                keywordSuggestions = true;
              };
            };
          };
        };
      };
    };
  };
}
