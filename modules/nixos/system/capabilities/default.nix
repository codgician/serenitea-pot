{
  lib,
  ...
}:
{
  options.codgician.system.capabilities = {
    hasSecretStorage = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether a secret storage backend (keyring/wallet) is available.
        Automatically set by GNOME or Plasma modules.
      '';
    };
  };
}
