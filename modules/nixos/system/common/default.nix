{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.system.common;
  configureNetworking =
    !(config ? proxmoxLXC) || !config.proxmoxLXC.enable || config.proxmoxLXC.manageNetwork;
  networkConfig = {
    MulticastDNS = true;
    LLMNR = true;
    LLDP = true;
  };
in
{
  config = lib.mkIf cfg.enable {
    # Enable systemd in initrd
    boot.initrd.systemd.enable = lib.mkIf (!config.boot.isContainer) true;

    # Console
    console = {
      font = "${pkgs.terminus_font}/share/consolefonts/ter-u14n.psf.gz";
      earlySetup = true;
      useXkbConfig = true;
    };

    systemd.services.systemd-vconsole-setup.unitConfig.After = "local-fs.target";

    # Set flake for auto upgrade
    system.autoUpgrade = {
      flake = "github:codgician/serenitea-pot";
      flags = [
        "--refresh"
        "--no-write-lock-file"
        "-L"
      ];
    };

    # Enable sandboxed nix builds
    nix.settings.sandbox = true;

    # Enable redistributable firmware
    hardware.enableAllFirmware = true;
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
    systemd.network.networks = lib.mkIf configureNetworking {
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

    # Locales
    i18n = {
      defaultLocale = "en_US.UTF-8";
      extraLocales = [ "zh_CN.UTF-8/UTF-8" ];
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
      dnsutils
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
      allowedUDPPorts = [
        5201
        5353
      ];
    };

    # Security
    users.mutableUsers = false;
    users.users.root.hashedPassword = "!";
    nix.settings.trusted-users = [
      "root"
      "@wheel"
    ];

    security = {
      audit.enable = !config.boot.isContainer;
      auditd.enable = !config.boot.isContainer;
      apparmor = {
        enable = !config.boot.isContainer;
        packages = with pkgs; [ apparmor-profiles ];
        killUnconfinedConfinables = true;
      };

      sudo-rs = {
        enable = true;
        execWheelOnly = true;
        wheelNeedsPassword = false;
      };
    };

    # Enlarge audit backlog limit
    boot.kernelParams = [ "audit_backlog_limit=8192" ];

    # Enable fail2ban
    services.fail2ban.enable = config.networking.firewall.enable;

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

    # ZFS common configurations
    services.zfs = lib.mkIf config.boot.zfs.enabled {
      autoScrub.enable = true;
      autoSnapshot.enable = true;
      expandOnBoot = "all";
      trim.enable = true;
      zed = {
        enableMail = config.codgician.services.postfix.enable;
        settings = {
          ZED_EMAIL_ADDR = lib.mkIf config.codgician.services.postfix.enable "codgician@outlook.com";
          ZED_NOTIFY_INTERVAL_SECS = 60 * 10;
          ZED_NOTIFY_VERBOSE = true;

          ZED_USE_ENCLOSURE_LEDS = true;
          ZED_SCRUB_AFTER_RESILVER = true;
        };
      };
    };
  };
}
