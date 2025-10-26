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

    fontFamily = lib.mkOption {
      type = with types; listOf str;
      default = [
        "Cascadia Code NF"
        "Cascadia Code"
        "monospace"
      ];
      description = "List of font families for VSCode editor.";
    };

    fontSize = lib.mkOption {
      type = types.int;
      default = 14;
      description = "Font size for VSCode editor.";
    };

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
            rooveterinaryinc.roo-cline
          ]
          ++ (with pkgs.vscode-marketplace-release; [
            github.copilot
            github.copilot-chat
            github.vscode-pull-request-github
            ms-vscode-remote.remote-ssh
          ]);

        userSettings = {
          chat = {
            agent.enabled = true;
            editor = {
              fontFamily = builtins.concatStringsSep ", " (builtins.map (x: "'${x}'") cfg.fontFamily);
              fontSize = 12; # not using the same size as editor
            };
            edits2.enabled = true;
            emptyState.history.enabled = true;
            mcp = {
              assisted.nuget.enabled = true;
              gallery.enable = true;
            };
          };
          editor = {
            fontFamily = builtins.concatStringsSep ", " (builtins.map (x: "'${x}'") cfg.fontFamily);
            inherit (cfg) fontSize;
          };
          terminal.integrated = {
            fontFamily = builtins.concatStringsSep ", " (builtins.map (x: "'${x}'") cfg.fontFamily);
            inherit (cfg) fontSize;
          };
          remote.SSH.defaultExtensions = builtins.map (
            ext: ext.vscodeExtUniqueId
          ) config.programs.vscode.profiles.default.extensions;
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
          "github.copilot.chat.editor.temporalContext.enabled" = true; # workaround
        };
      };
    };
  };
}
