{
  defaultThinkingLevel = "high";
  modelRoles = {
    default = "github-copilot/gpt-5.6-sol";
    smol = "github-copilot/gpt-5.6-luna";
    task = "github-copilot/claude-sonnet-5";
    slow = "github-copilot/claude-opus-5:xhigh";
    plan = "github-copilot/claude-opus-5:xhigh";
    advisor = "github-copilot/claude-sonnet-5:medium";
    vision = "github-copilot/gemini-3.1-pro-preview:high";
    designer = "github-copilot/gemini-3.1-pro-preview:high";
    commit = "github-copilot/gpt-5.4-mini";
    tiny = "github-copilot/gpt-5.4-mini";
  };
  modelProviderOrder = [ "github-copilot" ];
}
