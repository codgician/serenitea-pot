{ lib, agents }:
let
  # Dendro hides the upstream host from OMP's endpoint detection, but Copilot
  # rejects snapcompact's detail: "original".
  copilotModelOverrides = builtins.listToAttrs (
    map (m: {
      name = m.model;
      value.compat.supportsImageDetailOriginal = false;
    }) (agents.modelsFrom [ "github" ])
  );

  # OMP's LiteLLM discovery picks the wire API from the upstream provider name
  # and ignores the advertised `supported_endpoints`, so pin each model (and
  # its aliases) to its native LiteLLM surface from the same registry data.
  endpointApi =
    m:
    if builtins.elem "/v1/messages" (m.litellmModelInfo.supported_endpoints or [ ]) then
      "anthropic-messages"
    else if m.mode == "responses" then
      agents.modeToApi.responses
    else
      null;

  endpointModelOverrides = builtins.listToAttrs (
    lib.concatMap (
      m:
      map (name: {
        inherit name;
        value.api = endpointApi m;
      }) ([ m.model ] ++ m.aliases)
    ) (builtins.filter (m: endpointApi m != null) agents.textModels)
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
    baseUrl = "${agents.dendroUrl}/v1";
    api = agents.modeToApi.chat;
    # Plain API-key shaping; anthropic-messages otherwise defaults to OAuth-style requests.
    auth = "apiKey";
    authHeader = true;
    apiKey = agents.apiKeyCommand;
    discovery.type = "litellm";
    modelOverrides = lib.recursiveUpdate copilotModelOverrides endpointModelOverrides;
  };
}
