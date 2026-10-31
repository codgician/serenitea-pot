{ lib, osConfig }:
let
  textModels = osConfig.codgician.models.textGenerationModels;

  # Dendro hides the upstream host from OMP's endpoint detection, but Copilot
  # rejects snapcompact's detail: "original".
  copilotModelOverrides = builtins.listToAttrs (
    map (m: {
      name = m.model;
      value.compat.supportsImageDetailOriginal = false;
    }) (builtins.filter (m: m.provider == "github") textModels)
  );

  # OMP's LiteLLM discovery picks the wire API from the upstream provider name
  # and ignores the advertised `supported_endpoints`, so pin each model (and
  # its aliases) to its native LiteLLM surface from the same registry data.
  endpointApi =
    m:
    if builtins.elem "/v1/messages" (m.litellmModelInfo.supported_endpoints or [ ]) then
      "anthropic-messages"
    else if m.mode == "responses" then
      "openai-responses"
    else
      null;

  endpointModelOverrides = builtins.listToAttrs (
    lib.concatMap (
      m:
      map (name: {
        inherit name;
        value.api = endpointApi m;
      }) ([ m.model ] ++ m.aliases)
    ) (builtins.filter (m: endpointApi m != null) textModels)
  );
in
{
  "config.yml" = {
    defaultThinkingLevel = "high";
    modelRoles = {
      default = "dendro/claude-opus-5.5:medium";
      smol = "dendro/claude-haiku-5.5:medium";
      task = "dendro/claude-opus-5.5:medium";
      slow = "dendro/claude-opus-5.5:xhigh";
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
    # Plain API-key shaping; anthropic-messages otherwise defaults to OAuth-style requests.
    auth = "apiKey";
    authHeader = true;
    apiKey = "!cat ${osConfig.codgician.secrets.files."litellm-user-api-key".path}";
    discovery.type = "litellm";
    modelOverrides = lib.recursiveUpdate copilotModelOverrides endpointModelOverrides;
  };
}
