{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.system.common;
in
{
  options.codgician.system.common = {
    enable = lib.mkEnableOption "Enable common options shared accross all systems.";
  };

  config = lib.mkIf cfg.enable {

    # Use networkd
    networking.useNetworkd = true;

    # Enable resolved
    services.resolved = {
      enable = true;
      extraConfig = ''
        MulticastDNS=yes
        Cache=no-negative
      '';
    };

    # Time zone.
    time.timeZone = "Asia/Shanghai";

    # Select internationalisation properties.
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
      font = "Lat2-Terminus16";
      useXkbConfig = true;
    };

    # Zsh
    programs.zsh = {
      enable = true;
      enableCompletion = true;
    };
    
    # Common global packages
    environment.systemPackages = with pkgs; [
      vim
      fastfetch
      wget
      xterm
      htop
      aria2
    ];

    # Security
    users.mutableUsers = false;
    users.users.root.hashedPassword = "!";
    security.sudo.wheelNeedsPassword = false;
    nix.settings.trusted-users = [ "root" "@wheel" ];

    # OpenSSH
    services.openssh = {
      enable = true;
      openFirewall = true;
      settings.PasswordAuthentication = false;
    };

    # Some programs need SUID wrappers, can be configured further or are
    # started in user sessions.
    programs.mtr.enable = true;
    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };
}
