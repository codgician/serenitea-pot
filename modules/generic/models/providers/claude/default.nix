{ lib, modelLib, ... }:
{
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
