{ osConfig, ... }:
{
  config = {
    programs.gpg.enable = true;

    services = {
      # A desktop environment implies a login-session keyring (GNOME Keyring /
      # KDE Wallet) that owns SSH_AUTH_SOCK (GNOME: gcr-ssh-agent; Plasma:
      # programs.ssh.startAgent at system scope), so a separate home-manager
      # user agent there is both redundant and harmful (it would hijack
      # SSH_AUTH_SOCK in shell init). On headless hosts, keep it for interactive
      # `ssh-add`. Desktop-specific askpass wiring lives in the desktop modules.
      ssh-agent.enable = !osConfig.codgician.system.capabilities.hasDesktop;

      gpg-agent = {
        enable = true;
        enableSshSupport = false;
      };
    };
  };
}
