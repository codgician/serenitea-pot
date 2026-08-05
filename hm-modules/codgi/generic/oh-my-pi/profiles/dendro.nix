{
  defaultThinkingLevel = "high";
  modelRoles = {
    default = "dendro/gpt-5.6-sol";
    smol = "dendro/gpt-5.6-luna";
    task = "dendro/grok-4.5";
    slow = "dendro/gpt-5.6-sol:xhigh";
    plan = "dendro/gpt-5.6-sol:xhigh";
    advisor = "dendro/grok-4.5:high";
    vision = "dendro/gemini-3.6-flash:high";
    designer = "dendro/gemini-3.6-flash:high";
    commit = "dendro/gpt-5.6-luna";
    tiny = "dendro/gpt-5.6-luna";
  };
  modelProviderOrder = [ "dendro" ];
}
