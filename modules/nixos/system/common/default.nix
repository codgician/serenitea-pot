{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.system.common;
in
{
  config = lib.mkIf cfg.enable {
    # Set flake for auto upgrade
    system.autoUpgrade = {
      flake = "github:codgician/serenitea-pot";
      flags = [ "--refresh" "--no-write-lock-file" "-L" ];
    };

    # Enable sandboxed nix builds
    nix.settings.sandbox = true;

    # Enable redistributable firmware
    hardware.enableRedistributableFirmware = true;

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
      iperf3
    ];

    # Open firewall for iperf3
    networking.firewall = {
      allowedTCPPorts = [ 5201 ];
      allowedUDPPorts = [ 5201 ];
    };

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
      hostKeys = [{
        path = "/etc/ssh/ssh_host_ed25519_key";
        rounds = 100;
        type = "ed25519";
      }];
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
