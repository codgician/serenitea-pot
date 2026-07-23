{
  defaultThinkingLevel = "high";
  enabledModels = [
    "dendro/gemini-3.1-pro-preview"
    "dendro/gemini-3.5-flash"
  ];
  modelRoles = {
    default = "dendro/gemini-3.1-pro-preview:high";
    smol = "dendro/gemini-3.5-flash:low";
    task = "dendro/gemini-3.5-flash:high";
    slow = "dendro/gemini-3.1-pro-preview:high";
    plan = "dendro/gemini-3.1-pro-preview:high";
    advisor = "dendro/gemini-3.1-pro-preview:high";
    vision = "dendro/gemini-3.1-pro-preview:high";
    designer = "dendro/gemini-3.1-pro-preview:high";
    commit = "dendro/gemini-3.5-flash:low";
    tiny = "dendro/gemini-3.5-flash:low";
  };
}
