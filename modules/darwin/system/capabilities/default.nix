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

      A desktop environment also implies a login-session keyring; on Darwin
      this is always available via the macOS Keychain.
    '';
  };

  config.codgician.system.capabilities = {
    hasDesktop = true;
  };
}
