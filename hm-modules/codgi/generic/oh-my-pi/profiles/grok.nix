{
  defaultThinkingLevel = "medium";
  enabledModels = [ "dendro/grok-4.6" ];
  modelRoles = {
    default = "dendro/grok-4.6:medium";
    smol = "dendro/grok-4.6:low";
    task = "dendro/grok-4.6:medium";
    slow = "dendro/grok-4.6:high";
    plan = "dendro/grok-4.6:high";
    advisor = "dendro/grok-4.6:high";
    vision = "dendro/grok-4.6:high";
    designer = "dendro/grok-4.6:high";
    commit = "dendro/grok-4.6:low";
    tiny = "dendro/grok-4.6:low";
  };
}
