let
  version = "6.8.0";
  majorVersion = builtins.head (builtins.splitVersion version);
in
{ mobile-nixos, fetchurl, fetchpatch, lib, ... }: mobile-nixos.kernel-builder {
  inherit version;
  configfile = ./config.aarch64;

  src =
    let
      fileVersion = if (lib.hasSuffix ".0" version) then (lib.removeSuffix ".0" version) else version;
    in
    fetchurl {
      url = "mirror://kernel/linux/kernel/v${majorVersion}.x/linux-${fileVersion}.tar.xz";
      sha256 = "1wv5x7qhcd05m8m0myyqm2il6mha1sx11h7ppf8yjsxvx2jdwsf9";
    };

  patches = [
    # CHROMIUM: Revert "serial: 8250_mtk: Fix UART_EFR register address"
    # https://chromium-review.googlesource.com/c/chromiumos/third_party/kernel/+/3670640
    (fetchpatch {
      url = "https://github.com/torvalds/linux/commit/4cec85ca5a098fca3d49bda9976bccaca16a8876.patch";
      sha256 = "sha256-V5d1OSJro82LIWrlJ74m5xxF26dtEe7HZmoFgUX/HBc=";
    })
  ];

  isModular = true;
  isCompressed = false;
}
