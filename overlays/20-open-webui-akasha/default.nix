# Apply patches and create open-webui-akasha package

{ inputs, lib, system, ... }:

self: super:
let
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (super) system;
    config = {
      allowUnfree = true;
      cudaSupport = lib.systems.inspect.predicates.isLinux system;
      rocmSupport = lib.systems.inspect.predicates.isLinux system;
    };
  };

  patches = [
    # Add fish-speech support (#11230)
    ./fish-speech.patch
  ];

  # Patch branding
  postPatch = ''
    # Remove suffix in webui name
    substituteInPlace backend/open_webui/env.py \
      --replace-fail 'WEBUI_NAME += " (Open WebUI)"' 'WEBUI_NAME += ""' 
    # Customize PWA description
    substituteInPlace backend/open_webui/main.py \
      --replace-fail \
      'is an open, extensible, user-friendly interface for AI that adapts to your workflow.' \
      'is an Open WebUI based solution for learning and sharing knowledge.'
  '';

  open-webui-py312 = super.open-webui.override {
    python3Packages = unstablePkgs.python312Packages;
  };
in
{
  open-webui-akasha = open-webui-py312.overridePythonAttrs (
      oldAttrs:
      let
        frontend = open-webui-py312.passthru.frontend.overrideAttrs (oldAttrs': {
          # Apply patches to frontend
          patches = (if (oldAttrs' ? patches) then oldAttrs'.patches else [ ]) ++ patches;
          postPatch = oldAttrs'.postPatch + postPatch;
        });
      in
      {
        # Add all optional dependencies
        dependencies = oldAttrs.dependencies ++ oldAttrs.optional-dependencies.all;

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
