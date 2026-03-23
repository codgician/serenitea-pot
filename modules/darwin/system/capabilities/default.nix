{
  lib,
  ...
}:
{
  options.codgician.system.capabilities = {
    hasSecretStorage = lib.mkOption {
      type = lib.types.bool;
      default = true; # macOS Keychain is always available
      description = ''
        Whether a secret storage backend (keychain) is available.
        Defaults to true on Darwin as macOS Keychain is always available.
      '';
    };
  };
}
