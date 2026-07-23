{
  defaultThinkingLevel = "high";
  modelRoles = {
    default = "dendro/gpt-5.6-sol";
    smol = "dendro/gpt-5.4-mini";
    task = "dendro/claude-sonnet-5";
    slow = "dendro/claude-opus-4-8:xhigh";
    plan = "dendro/claude-opus-4-8:xhigh";
    advisor = "dendro/claude-sonnet-5:medium";
    vision = "dendro/gemini-3.1-pro-preview:high";
    designer = "dendro/gemini-3.1-pro-preview:high";
    commit = "dendro/kimi-k2.6";
    tiny = "dendro/gpt-5.4-mini";
  };
  modelProviderOrder = [ "dendro" ];
}
