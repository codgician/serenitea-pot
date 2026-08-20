{
  defaultThinkingLevel = "high";
  modelRoles = {
    default = "github-copilot/gpt-5.6-terra-1m:medium";
    smol = "github-copilot/gpt-5.6-luna:medium";
    task = "github-copilot/gpt-5.6-terra-1m:xhigh";
    slow = "github-copilot/gpt-5.6-sol-1m:medium";
    plan = "github-copilot/gpt-5.6-sol-1m:xhigh";
    advisor = "github-copilot/grok-4.6:high";
    vision = "github-copilot/gemini-3.7-flash:high";
    designer = "github-copilot/gemini-3.7-flash:high";
    commit = "github-copilot/gpt-5.6-luna:low";
    tiny = "github-copilot/gpt-5.6-luna:low";
  };
  modelProviderOrder = [ "github-copilot" ];
}
