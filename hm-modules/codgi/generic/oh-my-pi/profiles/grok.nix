{
  defaultThinkingLevel = "medium";
  enabledModels = [ "dendro/grok-4.5" ];
  modelRoles = {
    default = "dendro/grok-4.5:medium";
    smol = "dendro/grok-4.5:low";
    task = "dendro/grok-4.5:medium";
    slow = "dendro/grok-4.5:high";
    plan = "dendro/grok-4.5:high";
    advisor = "dendro/grok-4.5:high";
    vision = "dendro/grok-4.5:high";
    designer = "dendro/grok-4.5:high";
    commit = "dendro/grok-4.5:low";
    tiny = "dendro/grok-4.5:low";
  };
}
