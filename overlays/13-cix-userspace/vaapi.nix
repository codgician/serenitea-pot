{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  libva,
  libdrm,
  cix-vpu-driver,
  cix-media-engine,
}:

# CIX P1 VA-API back-end. Builds a libVA driver (`libcix_va_drv_video.so`)
# that drives the VPU through V4L2 M2M ioctls and uses the CIX Media Engine
# for video processing. Upstream assumes Debian BSP paths for both the VPU
# control header and CME; point those references at their Nix store inputs.
stdenv.mkDerivation {
  pname = "cix-vaapi";
  # Upstream has no version stamp or tags; fall back to the
  # nixpkgs-conventional `0-unstable-<commit-date>` form. The source
  # rev pinned below identifies the exact snapshot.
  version = "0-unstable-2026-07-20";

  src = fetchFromGitHub {
    owner = "cixtech";
    repo = "cix_vaapi";
    rev = "6e03daa4174f9cb704a7bb94024bf29ade09d4e3";
    hash = "sha256-363d/J+kpPGOQ8jHj+LNMyIx2TDLqF0ojdSG8hDam/A=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    libva
    libdrm
    cix-media-engine
  ];

  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail "''${CMAKE_SYSROOT}/usr/share/cix/include" \
                     '${cix-vpu-driver}/include/cix' \
      --replace-fail "''${CMAKE_SYSROOT}/usr/include/cme" \
                     '${cix-media-engine}/include/cme'
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 libcix_va_drv_video.so \
      "$out/lib/dri/cix_drv_video.so"
    runHook postInstall
  '';

  meta = with lib; {
    description = "VA-API back-end for the CIX P1 VPU";
    homepage = "https://github.com/cixtech/cix_vaapi";
    license = licenses.asl20;
    platforms = [ "aarch64-linux" ];
  };
}
