# Apply patches and create open-webui-akasha package

{ ... }:

self: super:
let
  patches = [
    # Support docling-serve 1.x (#15785)
    ./docling-v1.patch
    # Add fish-speech support (#11230)
    ./fish-speech.patch
  ];

  postPatch = ''
    # Remove suffix in webui name
    substituteInPlace backend/open_webui/env.py \
      --replace-fail 'WEBUI_NAME += " (Open WebUI)"' 'WEBUI_NAME += ""' 
    # Customize PWA description
    substituteInPlace backend/open_webui/main.py \
      --replace-fail \
      'Open WebUI is an open, extensible, user-friendly interface for AI that adapts to your workflow.' \
      'Akasha is an Open WebUI based solution for learning and sharing knowledge.'
  '';
in
{
  open-webui-akasha = super.open-webui.overridePythonAttrs (
    oldAttrs:
    let
      frontend = super.open-webui.passthru.frontend.overrideAttrs (oldAttrs': {
        # Apply patches to frontend
        patches = (if (oldAttrs' ? patches) then oldAttrs'.patches else [ ]) ++ patches;
        postPatch = oldAttrs'.postPatch + postPatch;
      });
    in
    {
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
