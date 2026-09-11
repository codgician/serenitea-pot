{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  # These archives reproduce the binaries read from Redrix ChromeOS 16805.10.0.
  # The ADL firmware and Brya topology have independent upstream versions.
  firmware = fetchurl {
    url = "https://storage.googleapis.com/chromeos-localmirror/distfiles/sof-binary-adl-3.4.tar.bz2";
    hash = "sha256-XFfFT8BQcw7qs2kTx6CpOqjvkDtTVTK9myizqDmxW0k=";
  };
  topology = fetchurl {
    url = "https://storage.googleapis.com/chromeos-localmirror/distfiles/sof-topology-brya-3.11.tar.xz";
    hash = "sha256-j1b5CKfgGdOq5kh7M9x3+VnSFaBl8qjKTtbdqQWtTJY=";
  };
  # Gentoo's SOF license referenced by both ChromiumOS packages; Gitiles TEXT
  # responses are base64 encoded. Keep the license alongside redistributed blobs.
  licenseText = fetchurl {
    url = "https://chromium.googlesource.com/chromiumos/overlays/chromiumos-overlay/+/276b9f4ab674d5fedef5c03a8387bcbd47aecc62/licenses/SOF?format=TEXT";
    hash = "sha256-c/W+L2wA93dlgSWjtl6ywc/ZmjT9K+vOAQbw4cB4dz0=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "redrix-sof-firmware";
  version = "adl-3.4-brya-3.11";
  srcs = [
    firmware
    topology
  ];
  sourceRoot = ".";
  dontFixup = true;

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    # Do not silently substitute a different "community" bundle with the same
    # filenames: these are the independently measured reference-device hashes.
    echo '46310d5fcf49ccf596b00396e90b7bb40ffe8b68f6789462d3db785ba04c3509  sof-binary-adl-3.4/sof-adl.ri' | sha256sum -c -
    echo '3c74a20e98cda6c163c9a4cdf889c7fb2f59029a9eb6e9d35d27162fb52b83ac  sof-topology-brya-3.11/sof-adl-max98390-rt5682.tplg' | sha256sum -c -
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 sof-binary-adl-3.4/sof-adl.ri "$out/lib/firmware/intel/sof/community/sof-adl.ri"
    install -Dm444 sof-binary-adl-3.4/sof-adl.ldc "$out/lib/firmware/intel/sof/community/sof-adl.ldc"
    install -Dm444 sof-topology-brya-3.11/sof-adl-max98390-rt5682.tplg "$out/lib/firmware/intel/sof-tplg/sof-adl-max98390-rt5682.tplg"
    mkdir -p "$out/share/licenses/redrix-sof-firmware"
    base64 -d ${licenseText} > "$out/share/licenses/redrix-sof-firmware/LICENSE"
    runHook postInstall
  '';

  meta = {
    description = "ChromeOS community ADL firmware and Brya topology matched to Redrix";
    homepage = "https://chromium.googlesource.com/chromiumos/overlays/board-overlays/";
    license = with lib.licenses; [
      bsd3
      mit
    ];
    sourceProvenance = [ lib.sourceTypes.binaryFirmware ];
    platforms = [ "x86_64-linux" ];
  };
}
