# Apply patches and create open-webui-akasha package

{ ... }:

self: super:
let
  patches = [
    # Add fish-speech support (#11230)
    ./fish-speech.patch
  ];
in
{
  open-webui-akasha = super.open-webui.overridePythonAttrs (
    oldAttrs:
    let
      frontend = super.open-webui.passthru.frontend.overrideAttrs (oldAttrs': {
        # Apply patches to frontend
        patches = (if (oldAttrs' ? patches) then oldAttrs'.patches else [ ]) ++ patches;
      });
    in
    {
      # Apply patches to backend
      patches = (if (oldAttrs ? patches) then oldAttrs.patches else [ ]) ++ patches;
      makeWrapperArgs = [ "--set FRONTEND_BUILD_DIR ${frontend}/share/open-webui" ];
      passthru = oldAttrs.passthru // {
        inherit frontend;
      };
    }
  );
}
