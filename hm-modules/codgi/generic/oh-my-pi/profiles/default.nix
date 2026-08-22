{ pkgs }:
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
      customDirectories = [ "${pkgs.nur.repos.codgician.agent-browser.src}/skills" ];
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

  dendroProfile = commonProfile // (import ./dendro.nix);

  familyProfileOverrides = {
    china = import ./china.nix;
    claude = import ./claude.nix;
    gemini = import ./gemini.nix;
    gpt = import ./gpt.nix;
    grok = import ./grok.nix;
    private = import ./private.nix;
  };
in
{
  dendro = dendroProfile;
  github-copilot = commonProfile // (import ./github-copilot.nix);
}
// builtins.mapAttrs (_name: profile: dendroProfile // profile) familyProfileOverrides
