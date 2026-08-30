{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  revision = "454c9bc6d08ade855a0cb7644de6493621e9a034";
  fetchFirmware =
    name: hash:
    fetchurl {
      url = "https://raw.githubusercontent.com/coolstar/max98390/${revision}/max98390/${name}";
      inherit hash name;
    };
in
stdenvNoCC.mkDerivation {
  pname = "redrix-max98390-firmware";
  version = "2024-02-13";

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm444 ${fetchFirmware "dsm_param_L_Google_Redrix.bin" "sha256-GHa/F9VZIK8+phetW0oAkrnYDeGqDQxlGtyho1N+nZU="} $out/lib/firmware/dsm_param_L_Google_Redrix.bin
    install -Dm444 ${fetchFirmware "dsm_param_R_Google_Redrix.bin" "sha256-9um9Gm1ec0UYixv0Ba8nEA6Mor0zlHIj9WwAniGA5ss="} $out/lib/firmware/dsm_param_R_Google_Redrix.bin
    install -Dm444 ${fetchFirmware "dsm_param_tt_L_Google_Redrix.bin" "sha256-GgDohyDqtZoeBr2J9QAR+6Dy9HEsyvEOETAPZZAFAeI="} $out/lib/firmware/dsm_param_tt_L_Google_Redrix.bin
    install -Dm444 ${fetchFirmware "dsm_param_tt_R_Google_Redrix.bin" "sha256-WBuLOR6npYyrOQ8OfLwMvbqJZWUobPdvdnlUyvrEEeA="} $out/lib/firmware/dsm_param_tt_R_Google_Redrix.bin

    runHook postInstall
  '';

  meta = with lib; {
    description = "MAX98390 DSM firmware for the Google Redrix Chromebook";
    homepage = "https://github.com/coolstar/max98390";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
