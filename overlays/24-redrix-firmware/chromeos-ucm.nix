{
  lib,
  stdenvNoCC,
  fetchzip,
  alsa-ucm-conf,
  noiseReduction ? false,
}:
stdenvNoCC.mkDerivation {
  pname = "redrix-chromeos-ucm";
  version = "16733.54.0";
  # Original Redrix UCM from the ChromiumOS release matching recovery 16733.54.0.
  # Hash the unpacked files: Gitiles archive timestamps can vary between fetches.
  src = fetchzip {
    url = "https://chromium.googlesource.com/chromiumos/overlays/board-overlays/+archive/0e50126e09cc069570ad4b19bc629254a5e5bdf5/overlay-brya/chromeos-base/chromeos-bsp-brya/files/redrix/audio/ucm-config/sof-rt5682.redrix.tar.gz";
    hash = "sha256-qiJFwXzJLVtowWMNAubQXJcTKImJvtazV5C8I7fN9ZQ=";
    stripRoot = false;
  };
  patches = [ ./ucm/linux-adaptation.patch ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/alsa"
    cp -rL ${alsa-ucm-conf}/share/alsa/. "$out/share/alsa/"
    chmod -R u+w "$out/share/alsa"
    card="$out/share/alsa/ucm2/conf.d/sof-rt5682"
    install -Dm444 sof-rt5682.redrix.conf "$card/sof-rt5682.conf"
    install -Dm644 HiFi.conf "$card/HiFi.conf"
    substituteInPlace "$card/HiFi.conf" \
      --replace-fail '@noiseReduction@' '${if noiseReduction then "on" else "off"}' \
      --replace-fail '@aecOff@' '${./sof-firmware/AEC_Off.bin}'
    runHook postInstall
  '';

  meta = {
    description = "Native ChromeOS Redrix UCM adapted for ALSA UCM2 and PipeWire";
    # Contains recovery-image processing payloads; redistribution is unassessed.
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
