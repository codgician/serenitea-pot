# Unified model registry assembled from provider descriptors.
{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  modelLib = import ./lib.nix { inherit lib; };

  registry = lib.genAttrs (lib.codgician.getFolderNames ./providers) (
    name:
    let
      inherit (import ./providers/${name} { inherit lib modelLib pkgs; }) provider;
    in
    lib.mapAttrs provider.transformer provider.models
  );
  flatModels = modelLib.flattenRegistry registry;
in
{
  options.codgician.models = {
    all = mkOption {
      type = types.listOf types.attrs;
      readOnly = true;
      description = "Flat list of all models with provider/model fields";
    };
    textGenerationModels = mkOption {
      type = types.listOf types.attrs;
      readOnly = true;
      description = "Models for text generation (mode = chat or responses)";
    };
    byProvider = mkOption {
      type = types.attrsOf (types.attrsOf types.attrs);
      readOnly = true;
      description = "Models organized by provider: provider → model → attrs";
    };
  };

  config.codgician.models = {
    byProvider = registry;
    all = flatModels;
    textGenerationModels = builtins.filter (
      model:
      builtins.elem model.litellmModelInfo.mode [
        "chat"
        "responses"
      ]
    ) flatModels;
  };
}
