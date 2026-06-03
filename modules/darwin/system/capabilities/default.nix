{
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
in
{
  options.codgician.system.capabilities = {
    hasDesktop = mkCapability ''
      Whether a desktop environment is installed.
      Always true on Darwin as macOS always provides the Aqua desktop.
    '';

    hasDesktopKeyring = mkCapability ''
      Whether a desktop keyring is available as part of the login session.
      Always true on Darwin as the macOS Keychain is always available.
    '';
  };

  config.codgician.system.capabilities = {
    hasDesktop = true;
    hasDesktopKeyring = true;
  };
}
