{
  defaultThinkingLevel = "high";
  enabledModels = [
    "dendro/deepseek-v4-flash"
    "dendro/deepseek-v4-pro"
    "dendro/minimax-m3"
    "dendro/glm-5.2"
  ];
  modelRoles = {
    default = "dendro/glm-5.2:high";
    smol = "dendro/deepseek-v4-flash:low";
    task = "dendro/deepseek-v4-flash:high";
    slow = "dendro/deepseek-v4-pro:high";
    plan = "dendro/glm-5.2:high";
    advisor = "dendro/minimax-m3";
    vision = "dendro/deepseek-v4-pro:high";
    designer = "dendro/deepseek-v4-pro:high";
    commit = "dendro/minimax-m3";
    tiny = "dendro/deepseek-v4-flash:low";
  };
}
