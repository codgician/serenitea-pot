{
  defaultThinkingLevel = "high";
  modelRoles = {
    default = "dendro/claude-sonnet-5:medium";
    smol = "dendro/gpt-5.6-luna:medium";
    task = "dendro/gpt-5.6-terra:xhigh";
    slow = "dendro/gpt-5.6-sol:medium";
    plan = "dendro/claude-opus-5:xhigh";
    advisor = "dendro/grok-4.6:high";
    vision = "dendro/gemini-3.7-flash:high";
    designer = "dendro/gemini-3.7-flash:high";
    commit = "dendro/gpt-5.6-luna:low";
    tiny = "dendro/gpt-5.6-luna:low";
  };
  modelProviderOrder = [ "dendro" ];
}
