{
  lib,
  stdenv,
  fetchFromGitHub,
}:

# CIX P1 board firmware blobs (Wi-Fi, Bluetooth, Mali GPU, AMD GPU,
# SFH/sensor microcode). Sourced from CIX's proprietary GitHub repo;
# these are redistributable but not built from source, so we tag the
# meta accordingly to keep `nixpkgs.config.allowUnfree` honest.
stdenv.mkDerivation {
  pname = "cix-firmware";
  version = "2026-06-29";

  src = fetchFromGitHub {
    owner = "cixtech";
    repo = "cix_proprietary__cix_proprietary";
    rev = "6b1952c90f1469436713f184756e404a43b6e2ad";
    hash = "sha256-Xey6x36zgkV5RSeBeFjcq40Pu4aVCPP1wyxjWyQkvGQ=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/firmware"
    # Each subdirectory under cix_module_fw/ already uses the layout that
    # the corresponding kernel driver expects (e.g. amdgpu/, qca/, fc6xe/,
    # lt7911/), so we just merge them into /lib/firmware.
    for sub in cix_module_fw/*/; do
      cp -a "$sub"/. "$out/lib/firmware/"
    done
    runHook postInstall
  '';

  meta = with lib; {
    description = "Proprietary firmware blobs for the CIX P1 (Sky1) SoC";
    homepage = "https://github.com/cixtech/cix_proprietary__cix_proprietary";
    license = licenses.unfreeRedistributableFirmware;
    platforms = [ "aarch64-linux" ];
  };
}
