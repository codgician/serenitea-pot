{
  defaultThinkingLevel = "high";
  modelRoles = {
    default = "github-copilot/gpt-6.2-sol:medium";
    smol = "github-copilot/gpt-6-luna:medium";
    task = "github-copilot/gpt-6.2-sol:medium";
    slow = "github-copilot/gpt-6.2-astra:xhigh";
    plan = "github-copilot/gpt-6.2-astra:medium";
    advisor = "github-copilot/gpt-6.2-astra:high";
    vision = "github-copilot/gpt-6.2-terra:medium";
    designer = "github-copilot/gpt-6.2-sol:high";
    commit = "github-copilot/gpt-6-luna:low";
    tiny = "github-copilot/gpt-6-luna:low";
  };
  modelProviderOrder = [ "github-copilot" ];
}
