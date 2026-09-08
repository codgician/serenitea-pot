{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation {
  pname = "redrix-max98390-firmware";
  version = "1.0";

  # Published by ChromiumOS's adl-max98390-dsm-param-brya package.
  src = fetchurl {
    url = "https://storage.googleapis.com/chromeos-localmirror/distfiles/dsm-param-redrix-1.0.tar.bz2";
    hash = "sha256-vuTCW/kEAXGJB9/3bCPsaWUXoQ+ao54nX/XcyYk5HIc=";
  };
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm444 dsm_param_L_Google_Redrix.bin $out/lib/firmware/dsm_param_L_Google_Redrix.bin
    install -Dm444 dsm_param_R_Google_Redrix.bin $out/lib/firmware/dsm_param_R_Google_Redrix.bin
    install -Dm444 dsm_param_tt_L_Google_Redrix.bin $out/lib/firmware/dsm_param_tt_L_Google_Redrix.bin
    install -Dm444 dsm_param_tt_R_Google_Redrix.bin $out/lib/firmware/dsm_param_tt_R_Google_Redrix.bin

    runHook postInstall
  '';

  meta = with lib; {
    description = "MAX98390 DSM firmware for the Google Redrix Chromebook";
    homepage = "https://chromium.googlesource.com/chromiumos/overlays/board-overlays/+/0e50126e09cc069570ad4b19bc629254a5e5bdf5/chipset-adl/media-libs/adl-max98390-dsm-param-brya/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
