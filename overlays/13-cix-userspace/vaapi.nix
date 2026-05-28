{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  libva,
  libdrm,
  cix-vpu-driver,
}:

# CIX P1 VA-API back-end. Builds a libVA driver (`libcix_va_drv_video.so`)
# that drives the VPU through V4L2 M2M ioctls. Upstream `CMakeLists.txt`
# hard-codes `/usr/share/cix/include` because the Debian package ships
# `mvx-v4l2-controls.h` there; we point it at the same header that lives
# in the VPU driver's own source tree (which we install under
# `cix-vpu-driver/include/cix/`) so the build remains hermetic.
stdenv.mkDerivation {
  pname = "cix-vaapi";
  # Upstream has no version stamp or tags; fall back to the
  # nixpkgs-conventional `0-unstable-<commit-date>` form. The source
  # rev pinned below identifies the exact snapshot.
  version = "0-unstable-2026-04-10";

  src = fetchFromGitHub {
    owner = "cixtech";
    repo = "cix_vaapi";
    rev = "22c4e2ef573092eb3d73ff9a26e4f5c6f8927730";
    hash = "sha256-b7G6hQt5zvrj/WA0cVHwH3nR2mk02wBgnb3rVwGi4n8=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    libva
    libdrm
  ];

  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail '/usr/share/cix/include' \
                     '${cix-vpu-driver}/include/cix'
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
