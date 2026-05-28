{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
  kernelModuleMakeFlags,
  kmod,
}:

let
  kernelDir = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "cix-vpu-driver";
  # Upstream `Makefile`/`driver/Kbuild` declares this as 1.0.0. The
  # source rev pinned below identifies precisely which snapshot of
  # 1.0.0 we built; `cix_mainline_dev` carries the version-gated fixes
  # for newer kernel APIs (MODULE_IMPORT_NS string form, dentry hlist
  # transition, etc.) — non-mainline branches are pinned to 6.6.
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "cixtech";
    repo = "cix_opensource__vpu_driver";
    rev = "eb86680abdf42d45f4b70aa2f7e321bc3be4b8f4";
    hash = "sha256-YyOsuomP+jpAOoRfYySeCmmK/EzL799WQukaaLMmDdA=";
  };

  # Upstream ships `driver/Kbuild` that already defines the module wiring
  # correctly (`-I$(src)`, `obj-$(CONFIG_VIDEO_LINLON) := amvx.o`, full
  # object list). The repo-root Makefile is a DKMS-style wrapper whose
  # EXTRA_CFLAGS depend on `$(PWD)` — which Kbuild reassigns under us —
  # plus it has CRLF endings that defeat simple substitution. So just
  # build directly from `driver/` using the in-tree Kbuild.
  sourceRoot = "${finalAttrs.src.name}/driver";

  nativeBuildInputs = [ kmod ] ++ kernel.moduleBuildDependencies;

  hardeningDisable = [
    "format"
    "pic"
  ];

  # The Kbuild gates the `amvx` module on `CONFIG_VIDEO_LINLON`. Nothing
  # else in the tree sets it, so promote it here just for our build.
  buildPhase = ''
    runHook preBuild
    make -C ${kernelDir} M=$PWD modules \
      ${lib.escapeShellArgs kernelModuleMakeFlags} \
      CONFIG_VIDEO_LINLON=m \
      KCFLAGS=-DCONFIG_VIDEO_LINLON=1
    runHook postBuild
  '';

  # No `modules_install` target in-tree; install `amvx.ko` manually into
  # the standard out-of-tree location so the NixOS module loader picks it
  # up. Also expose the uapi header for userspace consumers (cix_vaapi).
  installPhase = ''
    runHook preInstall
    install -Dm644 amvx.ko \
      "$out/lib/modules/${kernel.modDirVersion}/extra/amvx.ko"
    install -Dm644 linux/mvx-v4l2-controls.h \
      "$out/include/cix/mvx-v4l2-controls.h"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Out-of-tree V4L2 M2M driver for the CIX P1 (Sky1) VPU (amvx)";
    homepage = "https://github.com/cixtech/cix_opensource__vpu_driver";
    license = licenses.gpl2Only;
    platforms = [ "aarch64-linux" ];
  };
})
