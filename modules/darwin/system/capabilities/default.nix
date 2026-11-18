{ lib, ... }:
{
  # Derived fact that modules read; hosts must not set it.
  options.codgician.system.capabilities.hasDesktop = lib.mkOption {
    type = lib.types.bool;
    readOnly = true;
    internal = true;
    visible = false;
    default = true;
    description = ''
      Whether a desktop environment is installed: macOS always provides Aqua,
      and with it a login-session keyring (the Keychain).
    '';
  };
}
