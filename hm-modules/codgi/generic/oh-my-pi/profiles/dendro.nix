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
      smol = "dendro/claude-haiku-5.5:medium";
      task = "dendro/gpt-6.1-sol:medium";
      slow = "dendro/gpt-6.1-sol:xhigh";
      plan = "dendro/claude-opus-5.5:xhigh";
      advisor = "dendro/gpt-6.1-sol:high";
      vision = "dendro/gpt-6.1-terra:medium";
      designer = "dendro/claude-opus-5.5:high";
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
