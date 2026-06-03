{
  config,
  lib,
  ...
}:
let
  # A capability is a derived, read-only, internal boolean fact that modules
  # advertise to each other. Host configurations must not set these directly;
  # consumers should only read them.
  mkCapability =
    description:
    lib.mkOption {
      type = lib.types.bool;
      readOnly = true;
      internal = true;
      visible = false;
      inherit description;
    };

  # Desktop environments that provide a graphical session (and a keyring).
  hasDesktopEnvironment =
    (config.codgician.services.gnome.enable or false)
    || (config.codgician.services.plasma.enable or false);
in
{
  options.codgician.system.capabilities = {
    hasDesktop = mkCapability ''
      Whether a desktop environment is installed (e.g. GNOME or Plasma).
      Derived from the enabled desktop environment modules.

      A desktop environment also implies a graphical login session with a
      keyring (GNOME Keyring or KDE Wallet) that is unlocked via PAM. Note
      that such a keyring describes a desktop-session secret store; it does
      not imply the keyring is reachable from non-graphical sessions such as
      SSH, where it is typically locked.
    '';
  };

  config.codgician.system.capabilities = {
    hasDesktop = hasDesktopEnvironment;
  };
}
