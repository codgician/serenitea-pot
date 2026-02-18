{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.system.common;
  pubKeys = import (lib.codgician.secretsDir + "/pubkeys.nix");
  configureNetworking =
    !(config ? proxmoxLXC) || !config.proxmoxLXC.enable || config.proxmoxLXC.manageNetwork;
  networkConfig = {
    MulticastDNS = true;
    LLMNR = true;
    LLDP = true;
  };
in
{
  options.codgician.system.common = {
    audit.enable = lib.mkOption {
      default = false;
      description = "Linux kernel audits";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable systemd in initrd
    boot.initrd.systemd.enable = lib.mkIf (!config.boot.isContainer) true;

    # SSH in initrd for emergency remote access (e.g., disk unlock)
    # Usage: ssh -p 2222 root@<host> "zfs load-key <pool> && exit"
    # Enable per-host with: boot.initrd.network.ssh.enable = true;
    boot.initrd.network.ssh = {
      port = lib.mkDefault 2222;
      hostKeys = [ ./initrd_ssh_host_ed25519_key ];
      authorizedKeys = lib.mkDefault pubKeys.users.codgi;
    };

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

    # Configure zsh
    programs.zsh = {
      enable = true;
      enableCompletion = true;
    };

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

    # Common global packages
    environment.systemPackages =
      (with pkgs; [
        ethtool
        vim
        fastfetch
        wget
        tmux
        htop
        aria2
        iftop
        iperf3
        dnsutils
        net-tools
        sysstat
      ])
      ++ (with config.boot.kernelPackages; [
        turbostat
      ]);

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
      audit = {
        enable = cfg.audit.enable;
        backlogLimit = 8192;
      };

      auditd.enable = cfg.audit.enable;
      apparmor = {
        enable = cfg.audit.enable;
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
    boot.kernelParams =
      if cfg.audit.enable then
        [
          "audit=1"
          "audit_backlog_limit=${builtins.toString config.security.audit.backlogLimit}"
          "lsm=landlock,lockdown,yama,integrity,safesetid,apparmor,bpf"
        ]
      else
        [ "audit=0" ];

    # Enable fail2ban
    services.fail2ban.enable = config.networking.firewall.enable;

    # Limit journal size
    services.journald.extraConfig = ''
      SystemMaxUse=1G
      SystemMaxFileSize=32M
    '';

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
      ssh.startAgent = lib.mkIf (!config.services.gnome.gcr-ssh-agent.enable) true;
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
