# Unified model registry assembled from provider descriptors.
{
  config,
  lib,
  pkgs,
  outputs,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.codgician.models;
  modelLib = import ./lib.nix { inherit lib; };

  providerNames = lib.codgician.getFolderNames ./providers;
  providerDefinitions = builtins.listToAttrs (
    map (
      name:
      lib.nameValuePair name (
        import (./providers + "/${name}") {
          inherit
            config
            lib
            modelLib
            outputs
            pkgs
            ;
        }
      )
    ) providerNames
  );

  providerConfigs = lib.mapAttrs (_: definition: definition.provider) providerDefinitions;
  registry = lib.mapAttrs (
    _: providerCfg: lib.mapAttrs providerCfg.transformer providerCfg.models
  ) cfg.providers;
  flatModels = modelLib.flattenRegistry registry;
  providerAssertions = lib.concatLists (
    lib.mapAttrsToList (_: definition: definition.assertions or [ ]) providerDefinitions
  );
in
{
  options.codgician.models = {
    providers = lib.mapAttrs (
      _: definition:
      mkOption {
        type = modelLib.mkProviderType definition.modelType;
        inherit (definition) description;
      }
    ) providerDefinitions;

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

  config = {
    assertions = providerAssertions;
    codgician.models = {
      providers = providerConfigs;
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
  };
}
