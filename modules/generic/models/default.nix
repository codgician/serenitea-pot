# Unified model registry assembled from provider descriptors.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.codgician.models;
  modelLib = import ./lib.nix { inherit lib; };

  # A provider folder gives the type of its model specs, the specs and the
  # function that turns a checked spec into a registry entry.
  providers = lib.genAttrs (lib.codgician.getFolderNames ./providers) (
    name: import ./providers/${name} { inherit lib modelLib pkgs; }
  );

  registry = lib.mapAttrs (name: lib.mapAttrs providers.${name}.provider.transformer) cfg.providers;
  flatModels = lib.concatLists (
    lib.mapAttrsToList (
      provider: models: lib.mapAttrsToList (model: attrs: attrs // { inherit provider model; }) models
    ) registry
  );
in
{
  options.codgician.models = {
    providers = lib.mapAttrs (
      _: definition:
      mkOption {
        type = types.attrsOf definition.modelType;
        inherit (definition) description;
      }
    ) providers;

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
    providers = lib.mapAttrs (_: definition: definition.provider.models) providers;
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
