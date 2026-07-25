{ modelLib, ... }:
{
  description = "Google Gemini models";
  modelType = modelLib.basicModelType;
  provider = {
    transformer =
      name: spec:
      modelLib.mkModel {
        modelPrefix = "gemini";
        apiKeyEnv = "GEMINI_API_KEY";
        tags = [
          "google"
          "remote"
        ];
      } name (spec // { mode = "image_generation"; });
    models = {
      "gemini-3-pro-image-preview" = { };
      "gemini-3.1-flash-image-preview" = { };
      "gemini-2.5-flash-image" = { };
    };
  };
}
