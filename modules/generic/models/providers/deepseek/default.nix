{ modelLib, ... }:
let
  variants = {
    none.thinking.type = "disabled";
    high = {
      thinking.type = "enabled";
      reasoningEffort = "high";
    };
    max = {
      thinking.type = "enabled";
      reasoningEffort = "max";
    };
  };
in
{
  description = "DeepSeek models";
  modelType = modelLib.basicModelType;
  provider = {
    transformer = modelLib.mkModel {
      modelPrefix = "deepseek";
      apiKeyEnv = "DEEPSEEK_API_KEY";
      tags = [
        "deepseek"
        "remote"
      ];
    };
    models = {
      "deepseek-v4-flash".variants = variants;
      "deepseek-v4-pro".variants = variants;
    };
  };
}
