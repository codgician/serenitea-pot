{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.system.common;
  networkConfig = {
    MulticastDNS = true;
    LLMNR = true;
    LLDP = true;
  };
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

    # Enable resolved
    services.resolved = {
      enable = true;
      llmnr = "true";
      extraConfig = ''
        MulticastDNS=yes
        Cache=no-negative
      '';
    };

    # Enable mDNS
    systemd.network.networks = {
      "99-ethernet-default-dhcp" = { inherit networkConfig; };
      "99-wireless-client-dhcp" = { inherit networkConfig; };
    };
    networking.networkmanager = {
      dns = "systemd-resolved";
      connectionConfig = {
        "connection.mdns" = "2";
      };
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

    # Fonts
    fonts = {
      fontconfig.enable = true;
      fontDir.enable = true;
      enableGhostscriptFonts = true;
    };

    # Open firewall for iperf3 and mDNS
    networking.firewall = {
      allowedTCPPorts = [ 5201 ];
      allowedUDPPorts = [ 5201 5353 ];
    };

    # Security
    users.mutableUsers = false;
    users.users.root.hashedPassword = "!";
    security.sudo.wheelNeedsPassword = false;
    nix.settings.trusted-users = [ "root" "@wheel" ];

    security = {
      audit.enable = !config.boot.isContainer;
      auditd.enable = !config.boot.isContainer;
      apparmor.enable = !config.boot.isContainer;
    };

    # OpenSSH
    services.openssh = {
      enable = true;
      openFirewall = true;
      settings.PasswordAuthentication = false;
      hostKeys = [
        {
          path = "/etc/ssh/ssh_host_ed25519_key";
          rounds = 100;
          type = "ed25519";
        }
        {
          path = "/etc/ssh/ssh_host_rsa_key";
          bits = 4096;
          openSSHFormat = true;
          rounds = 100;
          type = "rsa";
        }
      ];
    };

    # Some programs need SUID wrappers, can be configured further or are
    # started in user sessions.
    programs = {
      mtr.enable = true;
      gnupg.agent.enable = true;
      ssh.startAgent = true;
    };

    security.pam.sshAgentAuth.enable = true;
  };
}
