{
  defaultThinkingLevel = "high";
  enabledModels = [
    "dendro/deepseek-v4-flash"
    "dendro/deepseek-v4-pro"
    "dendro/kimi-k2.6"
  ];
  modelRoles = {
    default = "dendro/deepseek-v4-pro:high";
    smol = "dendro/deepseek-v4-flash:low";
    task = "dendro/deepseek-v4-flash:high";
    slow = "dendro/deepseek-v4-pro:high";
    plan = "dendro/deepseek-v4-pro:high";
    advisor = "dendro/kimi-k2.6";
    vision = "dendro/deepseek-v4-pro:high";
    designer = "dendro/deepseek-v4-pro:high";
    commit = "dendro/kimi-k2.6";
    tiny = "dendro/deepseek-v4-flash:low";
  };
}
