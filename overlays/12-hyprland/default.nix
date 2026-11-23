{ lib, fromUnstable, ... }:

lib.composeManyExtensions [
  (
    final: prev:
    let
      # nixpkgs-unstable bumped wf-touch past the API hyprgrass expects (non-virtual
      # exceeds_tolerance and an assert(priv->timer) crash in gesture_t::reset).
      hyprgrassWfTouch = prev.wf-touch.overrideAttrs {
        version = "0-unstable-2024-03-11";
        src = prev.fetchFromGitHub {
          owner = "WayfireWM";
          repo = "wf-touch";
          rev = "8974eb0f6a65464b63dd03b842795cb441fb6403";
          hash = "sha256-MjsYeKWL16vMKETtKM5xWXszlYUOEk3ghwYI85Lv4SE=";
        };
      };
    in
    {
      # nixpkgs-unstable's hyprgrass predates Hyprland 0.57; pin to upstream's hl-0.57.2 tag.
      hyprlandPlugins = prev.hyprlandPlugins // {
        hyprgrass =
          (prev.hyprlandPlugins.hyprgrass.override { wf-touch = hyprgrassWfTouch; }).overrideAttrs
            {
              version = "0.8.2-hl-0.57.2";
              src = prev.fetchFromGitHub {
                owner = "horriblename";
                repo = "hyprgrass";
                rev = "50e166017adc294c0c780c123022deebe99a4b05";
                hash = "sha256-RcoDB1XNsGengdoZ3KCsbVGzex6oE7t9ZKkSao/1ctU=";
              };
            };
      };
    }
  )

  (fromUnstable [
    "aquamarine"
    "hyprcursor"
    "hyprgraphics"
    "hypridle"
    "hyprland"
    "hyprland-guiutils"
    "hyprland-protocols"
    "hyprland-qt-support"
    "hyprlandPlugins"
    "hyprlang"
    "hyprlauncher"
    "hyprlock"
    "hyprpaper"
    "hyprpicker"
    "hyprpolkitagent"
    "hyprpwcenter"
    "hyprshutdown"
    "hyprsunset"
    "hyprsysteminfo"
    "hyprtoolkit"
    "hyprutils"
    "hyprwayland-scanner"
    "hyprwire"
    "uwsm"
    "xdg-desktop-portal-hyprland"
  ])
]
