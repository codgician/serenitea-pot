{
  pkgs,
  osConfig,
  extraSkillDirectories ? [ ],
}:
let
  commonProfile = {
    setupVersion = 2;
    composer.shape = "box";
    personality = "pragmatic";

    providers.webSearch = "exa";

    statusLine.preset = "full";
    tools = {
      approvalMode = "yolo";
      discoveryMode = "auto";
    };
    secrets.enabled = true;
    task = {
      batch = true;
      maxConcurrency = 8;
      isolation = {
        mode = "auto";
        merge = "patch";
      };
      showResolvedModelBadge = true;
    };
    async.enabled = true;
    skills = {
      enabled = true;
      enableSkillCommands = true;
      enableCodexUser = false;
      enableClaudeUser = false;
      enableClaudeProject = true;
      enablePiUser = false;
      enablePiProject = true;
      enableAgentsUser = false;
      enableAgentsProject = true;
      customDirectories = [
        "${pkgs.llm-agents.agent-browser.src}/skills"
      ]
      ++ extraSkillDirectories;
    };
    advisor = {
      enabled = false;
      subagents = false;
      syncBacklog = "off";
    };
    memory.backend = "off";
    autolearn = {
      enabled = false;
      autoContinue = false;
    };
    github.enabled = true;
    share.store = "gist";
    compaction = {
      enabled = true;
      strategy = "snapcompact";
      midTurnEnabled = true;
      remoteEnabled = true;
      autoContinue = true;
    };
  };

  dendroProfile = import ./dendro.nix { inherit osConfig; };

  familyProfileOverrides = {
    china = import ./china.nix;
    private = import ./private.nix;
  };
in
builtins.mapAttrs
  (
    _name: profile:
    profile
    // {
      "config.yml" = commonProfile // profile."config.yml";
    }
  )
  (
    {
      dendro = dendroProfile;
      local = import ./local.nix;
      github-copilot."config.yml" = import ./github-copilot.nix;
    }
    // builtins.mapAttrs (
      _name: settings:
      dendroProfile
      // {
        "config.yml" = dendroProfile."config.yml" // settings;
      }
    ) familyProfileOverrides
  )
