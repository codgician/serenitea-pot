{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.bilibili;
  vaapiFeature = if cfg.gpuAcceleration == "nvidia" then "VaapiOnNvidiaGPUs" else "VaapiVideoDecoder";
in
{
  options.codgician.codgi.bilibili = {
    enable = lib.mkEnableOption "Bilibili desktop client";

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
    home.packages = [ pkgs.bilibili ];

    xdg.configFile = lib.optionalAttrs (cfg.gpuAcceleration != null) {
      "bilibili/bilibili-flags.conf".text = ''
        --ignore-gpu-blocklist
        --enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,${vaapiFeature},VaapiIgnoreDriverChecks,PlatformHEVCDecoderSupport
        --enable-gpu-rasterization
        --enable-zero-copy
        --disable-gpu-sandbox
      '';
    };
  };
}
