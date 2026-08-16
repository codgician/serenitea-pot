{
  defaultThinkingLevel = "high";
  modelRoles = {
    default = "github-copilot/gpt-5.6-sol-1m";
    smol = "github-copilot/gpt-5.6-luna";
    task = "github-copilot/grok-4.6";
    slow = "github-copilot/gpt-5.6-sol-1m:xhigh";
    plan = "github-copilot/gpt-5.6-sol-1m:xhigh";
    advisor = "github-copilot/grok-4.6:high";
    vision = "github-copilot/gemini-3.6-flash:high";
    designer = "github-copilot/gemini-3.6-flash:high";
    commit = "github-copilot/gpt-5.6-luna";
    tiny = "github-copilot/gpt-5.6-luna";
  };
  modelProviderOrder = [ "github-copilot" ];
}
