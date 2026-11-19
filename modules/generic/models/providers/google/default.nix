{ modelLib, ... }:
{
  description = "Google Gemini models";
  modelType = modelLib.basicModelType;
  provider = {
    transformer = modelLib.mkModel {
      modelPrefix = "gemini";
      apiKeyEnv = "GEMINI_API_KEY";
      tags = [
        "google"
        "remote"
      ];
    };
    models = {
      "gemini-3-pro-image-preview".mode = "image_generation";
      "gemini-3.1-flash-image-preview".mode = "image_generation";
      "gemini-2.5-flash-image".mode = "image_generation";
    };
  };
}
