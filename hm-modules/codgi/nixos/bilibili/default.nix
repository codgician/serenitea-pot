{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.bilibili;
  gpuFeatures =
    if cfg.gpuAcceleration == "nvidia" then
      "AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,VaapiOnNvidiaGPUs,VaapiIgnoreDriverChecks,PlatformHEVCDecoderSupport"
    else
      "AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,VaapiVideoDecoder,VaapiIgnoreDriverChecks,PlatformHEVCDecoderSupport";
in
{
  options.codgician.codgi.bilibili = {
    enable = lib.mkEnableOption "Bilibili desktop client";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.bilibili;
      defaultText = lib.literalExpression "pkgs.bilibili";
      description = "The Bilibili package to install.";
    };

    gpuAcceleration = lib.mkOption {
      type =
        with lib.types;
        nullOr (enum [
          "nvidia"
          "amd"
          "intel"
        ]);
      default = null;
      description = "GPU vendor for VA-API hardware video decoding, or null to leave acceleration unconfigured.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile = lib.optionalAttrs (cfg.gpuAcceleration != null) {
      "bilibili/bilibili-flags.conf".text = ''
        --ignore-gpu-blocklist
        --enable-features=${gpuFeatures}
        --enable-gpu-rasterization
        --enable-zero-copy
        --disable-gpu-sandbox
      '';
    };
  };
}
