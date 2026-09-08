{
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "redrix-sof-firmware";
  version = "16733.54.0";
  # Exact board-specific files from Google brya recovery 16733.54.0.
  # Kept locally for this experiment; redistribution has not been assessed.
  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    install -Dm444 ${./sof-firmware/sof-adl.ri} "$out/lib/firmware/intel/sof/redrix/sof-adl.ri"
    install -Dm444 ${./sof-firmware/sof-adl.ldc} "$out/lib/firmware/intel/sof/redrix/sof-adl.ldc"
    install -Dm444 ${./sof-firmware/sof-adl-max98390-rt5682.tplg} "$out/lib/firmware/intel/sof-tplg/redrix/sof-adl-max98390-rt5682.tplg"
    runHook postInstall
  '';
  meta = {
    description = "Matched Redrix SOF firmware and topology from ChromeOS recovery";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
