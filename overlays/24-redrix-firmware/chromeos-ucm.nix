{
  lib,
  stdenvNoCC,
  fetchzip,
  alsa-ucm-conf,
}:
stdenvNoCC.mkDerivation {
  pname = "redrix-chromeos-ucm";
  version = "16805.10.0";
  # Preserve R154 board controls, adapting the routes to the stock SOF topology.
  # Hash the unpacked files: Gitiles archive timestamps can vary between fetches.
  src = fetchzip {
    url = "https://chromium.googlesource.com/chromiumos/overlays/board-overlays/+archive/619bf55cd33588db1111f6481db62ad0ddc6dfd5/overlay-brya/chromeos-base/chromeos-bsp-brya/files/redrix/audio/ucm-config/sof-rt5682.redrix.tar.gz";
    hash = "sha256-WaYVIdb6tenRIk1Xh5YhzFuhQ5gWhuim1AQbsjGciVE=";
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
    runHook postInstall
  '';

  meta = {
    description = "Native ChromeOS Redrix UCM adapted for ALSA UCM2 and PipeWire";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
  };
}
