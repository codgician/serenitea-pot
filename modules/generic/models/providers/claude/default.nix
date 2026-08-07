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
        extraParams = lib.optionalAttrs (!lib.hasInfix "haiku" name) {
          guardrails = [ "claude_oauth_hook" ];
        };
      } name spec;
    inherit models;
  };
}
