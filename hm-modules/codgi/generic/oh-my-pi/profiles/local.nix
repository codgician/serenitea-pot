{
  "config.yml" = {
    defaultThinkingLevel = "high";
    modelRoles = {
      default = "thor/claude-opus-5.5:medium";
      smol = "thor/gpt-6-luna:medium";
      task = "thor/gpt-6.1-sol:medium";
      slow = "thor/gpt-6-astra:medium";
      plan = "thor/claude-opus-5.5:xhigh";
      advisor = "thor/grok-4.6:high";
      vision = "thor/gemini-3.7-flash:high";
      designer = "thor/gemini-3.7-flash:high";
      commit = "thor/gpt-6-luna:low";
      tiny = "thor/gpt-6-luna:low";
    };
    modelProviderOrder = [ "thor" ];
  };
  "models.yml".providers.thor = {
    baseUrl = "http://localhost:5120/v1";
    auth = "none";
    api = "openai-responses";
    discovery.type = "proxy";
    compat.supportsReasoningEffort = true;
  };
}
