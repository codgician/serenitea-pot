{
  "config.yml" = {
    defaultThinkingLevel = "high";
    modelRoles = {
      default = "thor/claude-opus-5.5:medium";
      smol = "thor/claude-haiku-5.5:medium";
      task = "thor/gpt-6.1-sol:medium";
      slow = "thor/gpt-6.1-sol:xhigh";
      plan = "thor/claude-opus-5.5:xhigh";
      advisor = "thor/gpt-6.1-sol:high";
      vision = "thor/gpt-6.1-terra:medium";
      designer = "thor/claude-opus-5.5:high";
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
