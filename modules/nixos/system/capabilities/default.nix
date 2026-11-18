{
  config,
  lib,
  ...
}:
{
  # Derived fact that modules read; hosts must not set it.
  options.codgician.system.capabilities.hasDesktop = lib.mkOption {
    type = lib.types.bool;
    readOnly = true;
    internal = true;
    visible = false;
    default = config.codgician.services.plasma.enable;
    description = ''
      Whether a graphical desktop is installed (Plasma).

      A desktop environment also implies a graphical login session with a
      keyring (KDE Wallet) that is unlocked via PAM. Such a keyring is a
      desktop-session secret store; it is typically locked in non-graphical
      sessions such as SSH.
    '';
  };
}
