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
    '';

    hasDesktopKeyring = mkCapability ''
      Whether a desktop keyring (e.g. GNOME Keyring or KDE Wallet) is
      available and unlocked as part of the graphical login session.
      Derived from the enabled desktop environment modules.

      Note: this describes a desktop-session secret store. It does not
      imply the keyring is reachable from non-graphical sessions such as
      SSH, where it is typically locked.
    '';
  };

  config.codgician.system.capabilities = {
    hasDesktop = hasDesktopEnvironment;
    hasDesktopKeyring = hasDesktopEnvironment;
  };
}
