{
  config,
  lib,
  osConfig,
  ...
}:
let
  cfg = config.codgician.codgi.droid;

  # Filter text generation models by allowed providers
  allowedProviders = [
    "github"
    "anthropic"
    "nvidia"
  ];

  filteredModels = builtins.filter (
    m: builtins.elem m.provider allowedProviders
  ) osConfig.codgician.models.textGenerationModels;

  # Transform to Droid format
  mkDroidModel = m: {
    model = m.model;
    displayName = m.model;
    baseUrl = "https://dendro.codgician.me/v1";
    apiKey = "\${LITELLM_API_KEY}";
    provider = "generic-chat-completion-api";
  };

  customModels = map mkDroidModel filteredModels;

  # Merge with existing settings
  settings = {
    inherit customModels;
  };
in
{
  options.codgician.codgi.droid = {
    enable = lib.mkEnableOption "Droid configuration";
  };

  config = lib.mkIf cfg.enable {
    # Write to ~/.factory/settings.local.json (per docs, merged with settings.json)
    home.file.".factory/settings.local.json".text = builtins.toJSON settings;
  };
}
