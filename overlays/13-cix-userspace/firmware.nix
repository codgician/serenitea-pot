{
  lib,
  stdenv,
  fetchgit,
}:

# CIX P1 board firmware blobs (Wi-Fi, Bluetooth, Mali GPU, AMD GPU,
# SFH/sensor microcode). Sourced from the CIX proprietary repo on
# GitLab — these are redistributable but not built from source, so we
# tag the meta accordingly to keep `nixpkgs.config.allowUnfree` honest.
#
# Note: `fetchFromGitLab` is unsuitable here because the upstream
# branch name contains slashes (`874c4/bbdf2/cix_beta2_radxa_dev`)
# which it interpolates into the tarball URL. `fetchgit` against the
# full ref handles slashed branch names correctly.
stdenv.mkDerivation {
  pname = "cix-firmware";
  version = "2025-06-18";

  src = fetchgit {
    url = "https://gitlab.com/cix-linux/cix_proprietary/cix_proprietary.git";
    rev = "e7cf222fb1643779c830d72cdf6b6c02a29d58e7";
    branchName = "874c4/bbdf2/cix_beta2_radxa_dev";
    hash = "sha256-LXLmCahe8XAfV+BVVlDp1zNaeCLcx6eMnZmSYQemj4U=";
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
    homepage = "https://gitlab.com/cix-linux/cix_proprietary/cix_proprietary";
    license = licenses.unfreeRedistributableFirmware;
    platforms = [ "aarch64-linux" ];
  };
}
