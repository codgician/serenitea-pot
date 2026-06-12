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
    apparmor.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "AppArmor mandatory access control (enforcement with journald-visible logs).";
    };

    audit.enable = lib.mkOption {
      type = lib.types.bool;
      # Disabled by default: on kernel 6.18.x the audit subsystem rejects every
      # AUDIT_SET netlink op with EOPNOTSUPP when AppArmor is an active LSM,
      # making `audit-rules-nixos.service` fail and flooding the kernel log with
      # "error in audit_log_subj_ctx". See https://github.com/NixOS/nixpkgs/issues/483085.
      # We keep AppArmor (which we actively enforce) and define no custom audit
      # rules, so audit is the lower-value subsystem to drop until the kernel
      # regression is fixed upstream. Re-enable per-host once resolved.
      default = false;
      description = "Linux kernel audit subsystem and auditd userspace daemon.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable systemd in initrd
    boot.initrd.systemd.enable = lib.mkIf (!config.boot.isContainer) true;

    # Use zstd compression for initrd to save ESP space
    boot.initrd.compressor = "zstd";

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
      font = "${pkgs.terminus_font}/share/consolefonts/ter-u16n.psf.gz";
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

    # Enable resolved
    services.resolved = {
      enable = true;
      settings.Resolve = {
        MulticastDNS = true;
        Cache = "no-negative";
        LLMNR = true;
      };
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
        htop
        aria2
        iftop
        iperf3
        dnsutils
        net-tools
        sysstat
      ])
      ++ (lib.optionals pkgs.stdenv.hostPlatform.isx86 (
        with config.boot.kernelPackages;
        [
          cpupower
          turbostat
        ]
      ));

    # Fonts
    fonts = {
      fontconfig.enable = true;
      fontDir.enable = true;
      enableGhostscriptFonts = true;
    };

    # Use nftables for firewall
    networking.nftables.enable = true;

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
    # Lock root unless another password mechanism is set
    users.users.root.hashedPassword = lib.mkIf (
      config.users.users.root.initialPassword == null
      && config.users.users.root.initialHashedPassword == null
      && config.users.users.root.password == null
      && config.users.users.root.hashedPasswordFile == null
    ) "!";
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
        # NixOS automatically appends "apparmor" to `security.lsm` and sets
        # `apparmor=1` when enabled, so no manual `lsm=` wiring is needed.
        enable = cfg.apparmor.enable;
        packages = with pkgs; [ apparmor-profiles ];
        killUnconfinedConfinables = true;
      };

      sudo-rs = {
        enable = true;
        execWheelOnly = true;
        wheelNeedsPassword = false;
      };

      # fwupd-refresh.service runs as the headless `fwupd-refresh` system user,
      # which has no logind session. polkit therefore treats it as inactive and
      # denies `refresh-remote` (allow_inactive=no), causing the metadata refresh
      # to fail with "Failed to obtain auth". Grant this user the action explicitly.
      polkit.extraConfig = lib.mkIf config.services.fwupd.enable ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.fwupd.refresh-remote" &&
              subject.user == "fwupd-refresh") {
            return polkit.Result.YES;
          }
        });
      '';
    };

    # systemd-boot common configurations
    boot.loader.systemd-boot = {
      configurationLimit = 10;
      edk2-uefi-shell.enable = true;
      memtest86.enable = pkgs.stdenv.hostPlatform.isx86;
      netbootxyz.enable = true;
    };

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
          bits = 4096;
          path = "/etc/ssh/ssh_host_rsa_key";
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

    # 26.11 will flip this default to `false`; pin the legacy value explicitly.
    boot.zfs.forceImportRoot = lib.mkIf config.boot.zfs.enabled (lib.mkDefault true);

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
