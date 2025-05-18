{ config, lib, ... }:
let
  cfg = config.codgician.system.common;
in
{
  config = lib.mkIf cfg.enable {
    # Enable OpenSSH
    services.openssh.enable = true;

    # Set identity path for agenix
    age.identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_rsa_key"
    ];

    # Enable Touch ID for sudo
    security.pam.services.sudo_local.touchIdAuth = true;

    environment = {
      # Disable ssh password authentication
      etc."ssh/sshd_config.d/110-no-password-authentication.conf".text = ''
        PasswordAuthentication no
        KbdInteractiveAuthentication no
      '';

      # Workaround lack of dbus
      variables."GSETTINGS_BACKEND" = "keyfile";
    };

    # zsh
    programs.zsh = {
      enable = true;
      promptInit = "";
    };

    # Unlock country-specific restrictions
    system.defaults.CustomSystemPreferences = {
      "/Library/Preferences/.GlobalPreferences.plist".Country = "US";
    };
  };
}
