{
  defaultThinkingLevel = "high";
  modelRoles = {
    default = "github-copilot/gpt-6-sol:medium";
    smol = "github-copilot/gpt-6-luna:medium";
    task = "github-copilot/gpt-6-sol:medium";
    slow = "github-copilot/gpt-6-astra:xhigh";
    plan = "github-copilot/gpt-6-astra:medium";
    advisor = "github-copilot/grok-4.7:high";
    vision = "github-copilot/gemini-3.8-flash:high";
    designer = "github-copilot/gemini-3.8-flash:high";
    commit = "github-copilot/gpt-6-luna:low";
    tiny = "github-copilot/gpt-6-luna:low";
  };
  modelProviderOrder = [ "github-copilot" ];
}
