{ lib, outputs, ... }:

final: prev:
let
  allModels = (import ../../modules/nixos/services/litellm/models.nix {
    pkgs = final;
    inherit lib outputs;
  }).all;

  models = lib.listToAttrs (map (m: lib.nameValuePair m.model_name { name = m.model_name; }) (
    lib.filter (m: builtins.elem (m.model_info.mode or "") [ "chat" "responses" ]) allModels
  ));

  configFile = final.writeText "opencode-config.json" (builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    provider.litellm = {
      npm = "@ai-sdk/openai-compatible";
      name = "Dendro";
      options.baseURL = "https://dendro.codgician.me/";
      inherit models;
    };
  });
in
{
  opencode-with-config = final.symlinkJoin {
    name = "opencode-with-config";
    paths = [ final.opencode ];
    nativeBuildInputs = [ final.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/opencode --set OPENCODE_CONFIG ${configFile}
    '';
    inherit (final.opencode) meta;
  };
}
