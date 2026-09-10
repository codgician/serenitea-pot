{
  lib,
  stdenvNoCC,
  fetchzip,
  gawk,
}:
stdenvNoCC.mkDerivation {
  pname = "redrix-volume-curve";
  version = "16733.54.0";
  # Redrix CRAS configuration from the same pinned ChromiumOS commit as the UCM.
  # Its sof-rt5682.card_settings matches recovery 16733.54.0 byte-for-byte.
  src = fetchzip {
    url = "https://chromium.googlesource.com/chromiumos/overlays/board-overlays/+archive/0e50126e09cc069570ad4b19bc629254a5e5bdf5/overlay-brya/chromeos-base/chromeos-bsp-brya/files/redrix/audio/cras-config.tar.gz";
    hash = "sha256-C9B6ACbMnjf4dcg3ALej1xVaPdA3JnqISobOFUBww24=";
    stripRoot = false;
  };

  nativeBuildInputs = [ gawk ];

  installPhase = ''
    runHook preInstall
    # [Speaker] db_at_<position> = <dB * 100>, positions 0..100, into a Lua table.
    curve=$(awk -F' = ' '
      /^\[Speaker\]/ { speaker = 1; next }
      /^\[/ { speaker = 0 }
      speaker && sub(/^ *db_at_/, "", $1) { db[$1] = $2; n++ }
      END {
        if (n != 101) exit 1
        printf "{ [0] = %d", db[0]
        for (i = 1; i <= 100; i++) printf ", %d", db[i]
        printf " }"
      }' sof-rt5682.card_settings)
    mkdir -p "$out/share/wireplumber/scripts/redrix"
    substitute ${./volume-curve.lua} \
      "$out/share/wireplumber/scripts/redrix/volume-curve.lua" \
      --replace-fail '@speakerCurve@' "$curve"
    runHook postInstall
  '';

  meta = {
    description = "ChromeOS Redrix speaker volume curve for WirePlumber";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}
