{ config, lib, ... }:
let
  cfg = config.codgician.services.intune;
in
{
  options.codgician.services.intune.printer = {
    enable = lib.mkEnableOption "the corporate Follow Me Print queue" // {
      default = true;
    };

    user = lib.mkOption {
      type = lib.types.strMatching "[a-zA-Z0-9._-]+";
      example = "johndoe";
      description = "Microsoft alias used for all jobs sent through this queue (without @microsoft.com).";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.printer.enable) {
    services.printing.enable = true;
    hardware.printers.ensurePrinters = [
      {
        name = "YSoftAsia-Lexmark";
        deviceUri = "lpd://${cfg.printer.user}@AZSEAKMYS11/YSOFTASIA-LEXMARK-MAC";
        model = "drv:///sample.drv/generic.ppd";
        ppdOptions.printer-is-shared = "false";
      }
    ];
  };
}
