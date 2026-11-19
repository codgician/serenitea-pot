{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.easyeffects;
in
{
  options.codgician.codgi.easyeffects = {
    enable = lib.mkEnableOption "EasyEffects audio effects daemon";
    package = lib.mkPackageOption pkgs "easyeffects" { };
  };

  config = lib.mkIf cfg.enable {
    # Run EasyEffects as a systemd user service tied to graphical-session.target
    # rather than relying on its own GUI-driven "Autostart on login" toggle: that
    # toggle only writes ~/.config/autostart/com.github.wwmm.easyeffects.desktop
    # the first time it's flipped in the running app (non-reproducible from Nix),
    # and even then systemd-xdg-autostart-generator can silently skip the entry
    # when Exec="easyeffects" isn't resolvable in its generator-time PATH
    # (see https://github.com/wwmm/easyeffects/issues/4738). A declarative
    # systemd user unit with an absolute ExecStart sidesteps both failure modes.
    services.easyeffects = {
      enable = true;
      inherit (cfg) package;
    };

    # Empty group: dropping it changes the config script plasma-manager generates.
    programs.plasma.configFile."easyeffects/db/easyeffectsrc".Window = { };
  };
}
