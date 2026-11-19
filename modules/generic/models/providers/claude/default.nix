{ lib, modelLib, ... }:
{
  description = "Anthropic Claude subscription models";
  modelType = modelLib.generatedModelType;
  provider = {
    transformer = modelLib.mkGeneratedModel {
      modelPrefix = "anthropic";
      apiKeyEnv = "CLAUDE_CODE_OAUTH_TOKEN";
      tags = [
        "anthropic"
        "remote"
      ];
    };
    models = lib.importJSON ./models.json;
  };
}
