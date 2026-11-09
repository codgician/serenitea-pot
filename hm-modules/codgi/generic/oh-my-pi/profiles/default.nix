{
  pkgs,
  osConfig,
  extraSkillDirectories ? [ ],
}:
let
  commonProfile = {
    composer.shape = "box";
    personality = "pragmatic";

    modelRoles.web = "web/exa";

    statusLine.preset = "full";
    tools.approvalMode = "yolo";
    isolation.backend = "auto";
    secrets.enabled = true;
    task = {
      batch = true;
      maxConcurrency = 8;
      isolation = {
        enabled = true;
        merge = "patch";
      };
      agentAdvisor.task = "off";
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
      methodOrder = [
        "snapcompact"
        "remote"
        "soft"
      ];
      midTurnEnabled = true;
      autoContinue = true;
    };
  };

  dendroProfile = import ./dendro.nix {
    inherit (pkgs) lib;
    inherit osConfig;
  };

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
      # Deep merge so profile model roles add to the shared web role.
      "config.yml" = pkgs.lib.recursiveUpdate commonProfile profile."config.yml";
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
