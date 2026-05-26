{ inputs, lib }:
let
  patchDir = "${inputs.cix-linux-main}/patches-6.18";
  patches = builtins.sort (a: b: a < b) (
    builtins.filter (lib.hasSuffix ".patch") (lib.codgician.getRegularFileNames patchDir)
  );
  cixConfigEntry = {
    name = "cix-sky1-builtin-config";
    patch = null;
    structuredExtraConfig = with lib.kernel; {
      USB_CDNS_SUPPORT = yes;
      USB_CDNSP = yes;
      USB_CDNSP_HOST = yes;
    };
  };
in
(map (name: {
  inherit name;
  patch = "${patchDir}/${name}";
}) patches)
++ [ cixConfigEntry ]
