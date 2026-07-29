# Apply patches and create open-webui-akasha package

{ ... }:

final: prev:
let
  patches = [
    # Improve CJK sentence splitting for TTS
    ./cjk-sentence-splitting.patch
  ];

  # Remove the upstream branding suffix from the configured web UI name.
  postPatch = ''
    substituteInPlace backend/open_webui/env.py \
      --replace-fail "WEBUI_NAME += ' (Open WebUI)'" 'WEBUI_NAME += ""'
  '';
in
{
  open-webui-akasha = final.open-webui.overridePythonAttrs (
    oldAttrs:
    let
      frontend = final.open-webui.passthru.frontend.overrideAttrs (oldAttrs': {
        # Apply patches to frontend
        patches = (if (oldAttrs' ? patches) then oldAttrs'.patches else [ ]) ++ patches;
        postPatch = oldAttrs'.postPatch + postPatch;
      });
    in
    {
      # Add all optional dependencies
      dependencies = oldAttrs.dependencies ++ oldAttrs.optional-dependencies.postgres;

      # Apply patches to backend
      patches = (if (oldAttrs ? patches) then oldAttrs.patches else [ ]) ++ patches;
      postPatch = oldAttrs.postPatch + postPatch;
      makeWrapperArgs = [ "--set FRONTEND_BUILD_DIR ${frontend}/share/open-webui" ];
      passthru = oldAttrs.passthru // {
        inherit frontend;
      };
    }
  );
}
