{ modelLib, ... }:
{
  description = "xAI models";
  modelType = modelLib.basicModelType;
  provider = {
    transformer = modelLib.mkModel {
      modelPrefix = "xai";
      tags = [
        "xai"
        "remote"
      ];
      extraParams.use_xai_oauth = true;
    };
    models = { };
  };
}
