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
  pname = "cix-npu-driver";
  # Upstream `armchina-npu/Makefile` sets KMD_VERSION=5.11.0; the
  # source rev below pins which snapshot of 5.11.0 we built.
  # `cix_mainline_dev` matches the VPU driver branch and carries the
  # equivalent kernel-API gates for ≥6.13.
  version = "5.11.0";

  src = fetchFromGitHub {
    owner = "cixtech";
    repo = "cix_opensource__npu_driver";
    rev = "193d3650645b1d3de9794aa024675c755d864d57";
    hash = "sha256-eq95TOZwG7lisyq5koSaoRK4QB+QVQcgDJj+3Ekgf2s=";
  };
  sourceRoot = "${finalAttrs.src.name}/driver";

  nativeBuildInputs = [ kmod ] ++ kernel.moduleBuildDependencies;

  hardeningDisable = [
    "format"
    "pic"
  ];

  # Upstream npu.mk hard-codes these env vars; reproduce them here so the
  # in-tree Makefile selects the Zhouyi v3 / Sky1 (non-Android) variant
  # consistent with the CIX P1 hardware on sandrone.
  makeFlags = kernelModuleMakeFlags ++ [
    "COMPASS_DRV_BTENVAR_KPATH=${kernelDir}"
    "COMPASS_DRV_BTENVAR_KMD_VERSION=5.11.0"
    "BUILD_AIPU_VERSION_KMD=BUILD_ZHOUYI_V3"
    "BUILD_TARGET_PLATFORM_KMD=BUILD_PLATFORM_SKY1"
    "BUILD_NPU_DEVFREQ=y"
  ];

  # Same `$(PWD)` clobbering issue as the VPU driver — Kbuild rewrites
  # PWD to the kernel build dir when invoked via `-C ... M=...`. The
  # `cix_mainline_dev` Makefile uses `$(PWD)` in BOTH `EXTRA_CFLAGS` and
  # the newer `ccflags-y` line; patch both, leaving the outer
  # `M=$(PWD)` recipe alone so the source-tree make still invokes the
  # kernel build correctly.
  postPatch = ''
    substituteInPlace Makefile \
      --replace-fail '-I$(PWD)/armchina-npu/ -I$(PWD)/armchina-npu/include -I$(PWD)/armchina-npu/zhouyi' \
                     '-I$(M)/armchina-npu/ -I$(M)/armchina-npu/include -I$(M)/armchina-npu/zhouyi'
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 aipu.ko \
      "$out/lib/modules/${kernel.modDirVersion}/extra/aipu.ko"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Out-of-tree driver for the CIX P1 (Sky1) Zhouyi v3 NPU (aipu)";
    homepage = "https://github.com/cixtech/cix_opensource__npu_driver";
    license = licenses.gpl2Only;
    platforms = [ "aarch64-linux" ];
  };
})
