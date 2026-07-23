{
  defaultThinkingLevel = "high";
  enabledModels = [
    "dendro/claude-haiku-4-5"
    "dendro/claude-sonnet-4-6"
    "dendro/claude-sonnet-5"
    "dendro/claude-opus-4-6"
    "dendro/claude-opus-4-7"
    "dendro/claude-opus-4-8"
  ];
  modelRoles = {
    default = "dendro/claude-sonnet-5";
    smol = "dendro/claude-haiku-4-5";
    task = "dendro/claude-sonnet-5";
    slow = "dendro/claude-opus-4-8:xhigh";
    plan = "dendro/claude-opus-4-8:xhigh";
    advisor = "dendro/claude-opus-4-8:high";
    vision = "dendro/claude-sonnet-5:high";
    designer = "dendro/claude-sonnet-5:high";
    commit = "dendro/claude-haiku-4-5";
    tiny = "dendro/claude-haiku-4-5";
  };
}
