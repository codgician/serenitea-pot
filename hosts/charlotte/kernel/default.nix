{ mobile-nixos, fetchurl, fetchpatch, lib, kernel, ... }: mobile-nixos.kernel-builder {
  inherit (kernel) src version;
  configfile = ./config.aarch64;

  patches = [
    # CHROMIUM: Revert "serial: 8250_mtk: Fix UART_EFR register address"
    # https://chromium-review.googlesource.com/c/chromiumos/third_party/kernel/+/3670640
    (fetchpatch {
      url = "https://github.com/torvalds/linux/commit/4cec85ca5a098fca3d49bda9976bccaca16a8876.patch";
      sha256 = "sha256-V5d1OSJro82LIWrlJ74m5xxF26dtEe7HZmoFgUX/HBc=";
    })

    # Enable video encoder and decoder
    (fetchpatch {
      url = "https://gitlab.com/postmarketOS/pmaports/-/raw/497374e29085c6bfaa2a95113cd65a5719274cca/device/community/linux-postmarketos-mediatek-mt8183/arm64-dts-mediatek-mt8183-Add-video-encoder-decoder.patch";
      sha256 = "sha256-0OLWecwVxEFVmh3tcPL/Zfr8px+Q96jTSxbNk/WQuGo=";
    })

    # Add missing GPU clocks
    (fetchpatch {
      url = "https://gitlab.com/postmarketOS/pmaports/-/raw/497374e29085c6bfaa2a95113cd65a5719274cca/device/community/linux-postmarketos-mediatek-mt8183/arm64-dts-mediatek-mt8183-Add-missing-GPU-clocks.patch";
      sha256 = "sha256-gvfmK2FMbThBwo3Fj68/+H9mRdax0Sic+hL9NYj1yrQ=";
    })
  ];

  isModular = true;
  isCompressed = false;
}
