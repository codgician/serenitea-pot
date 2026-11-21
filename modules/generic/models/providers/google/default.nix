{ lib, modelLib, ... }:
{
  description = "Google Gemini models through the Gemini Developer API";
  modelType = modelLib.generatedModelType;
  provider = {
    transformer = modelLib.mkGeneratedModel {
      modelPrefix = "gemini";
      apiKeyEnv = "GEMINI_API_KEY";
      tags = [
        "google"
        "remote"
      ];
    };
    # Text models are refreshed by updater.sh; the Gemini model list does not
    # tell image models apart, so they are listed here.
    models = lib.importJSON ./models.json // {
      "gemini-3-pro-image-preview".mode = "image_generation";
      "gemini-3.1-flash-image-preview".mode = "image_generation";
      "gemini-2.5-flash-image".mode = "image_generation";
    };
  };
}
