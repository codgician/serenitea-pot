{ modelLib, ... }:
{
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
