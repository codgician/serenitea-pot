{ modelLib, ... }:
{
  description = "ChatGPT models";
  modelType = modelLib.basicModelType;
  provider = {
    transformer = modelLib.mkModel {
      modelPrefix = "chatgpt";
      tags = [
        "chatgpt"
        "remote"
      ];
      extraParams.stream = "True";
    };
    models = { };
  };
}
