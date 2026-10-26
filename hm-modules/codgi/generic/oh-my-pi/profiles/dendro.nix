{ osConfig }:
let
  # Dendro hides the upstream host from OMP's endpoint detection, but Copilot
  # rejects snapcompact's detail: "original".
  copilotModelOverrides = builtins.listToAttrs (
    map (m: {
      name = m.model;
      value.compat.supportsImageDetailOriginal = false;
    }) (builtins.filter (m: m.provider == "github") osConfig.codgician.models.textGenerationModels)
  );
in
{
  "config.yml" = {
    defaultThinkingLevel = "high";
    modelRoles = {
      default = "dendro/claude-opus-5.5:medium";
      smol = "dendro/gpt-6-luna:medium";
      task = "dendro/gpt-6.1-sol:medium";
      slow = "dendro/gpt-6-astra:medium";
      plan = "dendro/claude-opus-5.5:xhigh";
      advisor = "dendro/grok-4.6:high";
      vision = "dendro/gemini-3.7-flash:high";
      designer = "dendro/gemini-3.7-flash:high";
      commit = "dendro/gpt-6-luna:low";
      tiny = "dendro/gpt-6-luna:low";
    };
    modelProviderOrder = [ "dendro" ];
  };
  "models.yml".providers.dendro = {
    baseUrl = "https://dendro.codgician.me/v1";
    api = "openai-completions";
    authHeader = true;
    apiKey = "!cat ${osConfig.codgician.secrets.files."litellm-user-api-key".path}";
    discovery.type = "litellm";
    modelOverrides = copilotModelOverrides;
  };
}
