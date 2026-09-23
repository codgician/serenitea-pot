{
  defaultThinkingLevel = "high";
  modelRoles = {
    default = "dendro/claude-opus-5.5:medium";
    smol = "dendro/gpt-6-luna:medium";
    task = "dendro/gpt-6-sol:medium";
    slow = "dendro/gpt-6-astra:medium";
    plan = "dendro/claude-opus-5.5:xhigh";
    advisor = "dendro/grok-4.6:high";
    vision = "dendro/gemini-3.7-flash:high";
    designer = "dendro/gemini-3.7-flash:high";
    commit = "dendro/gpt-6-luna:low";
    tiny = "dendro/gpt-6-luna:low";
  };
  modelProviderOrder = [ "dendro" ];
}
