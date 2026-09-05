{
  defaultThinkingLevel = "high";
  enabledModels = [
    "dendro/gpt-5.2"
    "dendro/gpt-5.2-codex"
    "dendro/gpt-5.3-codex"
    "dendro/gpt-5.4"
    "dendro/gpt-5.4-mini"
    "dendro/gpt-5.5"
    "dendro/gpt-5.6-luna"
    "dendro/gpt-5.6-terra"
    "dendro/gpt-5.6-sol"
    "dendro/gpt-6-astra"
  ];
  modelRoles = {
    default = "dendro/gpt-5.6-terra:high";
    smol = "dendro/gpt-5.4-mini";
    task = "dendro/gpt-5.6-luna:medium";
    slow = "dendro/gpt-6-astra:xhigh";
    plan = "dendro/gpt-5.6-sol:xhigh";
    advisor = "dendro/gpt-5.5:high";
    vision = "dendro/gpt-5.5:medium";
    designer = "dendro/gpt-5.5:medium";
    commit = "dendro/gpt-5.4-mini";
    tiny = "dendro/gpt-5.4-mini";
  };
}
