{ modelLib, ... }:
{
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
