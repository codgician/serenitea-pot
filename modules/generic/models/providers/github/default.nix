{ lib, modelLib, ... }:
let
  data = builtins.fromJSON (builtins.readFile ./models.json);
  modelName =
    id:
    if id == "mai-code-1-flash-picker" then
      "mai-code-1-flash"
    else if lib.hasPrefix "claude-" id then
      lib.replaceStrings [ "." ] [ "-" ] id
    else
      id;
  names = map modelName (builtins.attrNames data);
  models =
    assert builtins.length names == builtins.length (lib.unique names);
    lib.mapAttrs' (id: spec: lib.nameValuePair (modelName id) (spec // { path = id; })) data;
in
{
  description = "GitHub Copilot models";
  modelType = modelLib.generatedModelType;
  provider = {
    transformer = modelLib.mkGeneratedModel {
      modelPrefix = "github_copilot";
      tags = [
        "github"
        "remote"
      ];
    };
    inherit models;
  };
}
