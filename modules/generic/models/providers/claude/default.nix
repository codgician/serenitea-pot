{ lib, modelLib, ... }:
let
  models = builtins.fromJSON (builtins.readFile ./models.json);
in
{
  description = "Anthropic Claude subscription models";
  modelType = modelLib.generatedModelType;
  provider = {
    transformer =
      name: spec:
      modelLib.mkGeneratedModel {
        modelPrefix = "anthropic";
        apiKeyEnv = "CLAUDE_CODE_OAUTH_TOKEN";
        tags = [
          "anthropic"
          "remote"
        ];
        extraParams = lib.optionalAttrs (!(lib.hasInfix "haiku" name)) {
          prompt_id = "claude";
        };
      } name spec;
    inherit models;
  };
}
