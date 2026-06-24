{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.pi-coding-agent;
in
{
  options.codgician.codgi.pi-coding-agent = {
    enable = lib.mkEnableOption "pi-coding-agent";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.pi-coding-agent;
      defaultText = lib.literalExpression "pkgs.pi-coding-agent";
      description = ''
        The pi-coding-agent package to install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
