{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.intune;

  # GlobalProtect VPN helper for off-site Intune compliance: authenticates
  # via Microsoft SSO (gpauth, driven in Microsoft Edge) and feeds the
  # resulting cookie to gpclient.
  msftvpn = pkgs.writeShellApplication {
    name = "msftvpn";
    text = ''
      portal="${cfg.vpn.portal}"

      case "''${1:-connect}" in
        connect)
          ${pkgs.gpauth}/bin/gpauth \
            --fix-openssl \
            --browser ${pkgs.microsoft-edge}/bin/microsoft-edge-stable \
            "$portal" \
          | ${config.security.wrapperDir}/sudo \
              ${pkgs.gpclient}/bin/gpclient \
              --fix-openssl \
              connect \
              --disable-ipv6 \
              --cookie-on-stdin \
              "$portal"
          ;;
        disconnect)
          exec ${config.security.wrapperDir}/sudo \
            ${pkgs.gpclient}/bin/gpclient disconnect --wait 3
          ;;
        help|-h|--help)
          echo "Usage: msftvpn [connect|disconnect]"
          ;;
        *)
          echo "Usage: msftvpn [connect|disconnect]" >&2
          exit 2
          ;;
      esac
    '';
  };
  intuneRegisterDevice = pkgs.writers.writePython3Bin "intune-register-device" {
    libraries = [ pkgs.python3Packages.dbus-next ];
    makeWrapperArgs = [
      "--set"
      "INTUNE_DSREG"
      "${cfg.packages.microsoft-identity-broker}/bin/dsreg"
      "--set"
      "INTUNE_SYSTEMCTL"
      "${pkgs.systemd}/bin/systemctl"
    ];
  } (builtins.readFile ./register-device.py);
in
{
  options.codgician.services.intune = {
    enable = lib.mkEnableOption "Microsoft Intune enrollment (identity broker, Intune daemon/agent, and compliance tooling)";

    packages = {
      intune-portal = lib.mkOption {
        type = lib.types.package;
        default = pkgs.intune-portal;
        defaultText = lib.literalExpression "pkgs.intune-portal";
        description = "Intune Portal package (provides intune-daemon and intune-agent).";
      };

      microsoft-identity-broker = lib.mkOption {
        type = lib.types.package;
        default = pkgs.microsoft-identity-broker;
        defaultText = lib.literalExpression "pkgs.microsoft-identity-broker";
        description = "Microsoft Identity Device Broker package.";
      };

    };
    vpn = {
      enable = lib.mkEnableOption "GlobalProtect VPN helper (msftvpn) for off-site Intune compliance";

      portal = lib.mkOption {
        type = lib.types.str;
        default = "msftvpn-alt.ras.microsoft.com";
        defaultText = "''msftvpn-alt.ras.microsoft.com''";
        description = "GlobalProtect VPN portal hostname.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    {
      # Required for TLS support in WebKitGTK (used by Intune Portal authentication)
      services.gnome.glib-networking.enable = true;

      services.dbus.packages = [ cfg.packages.microsoft-identity-broker ];
      services.pcscd.enable = true;

      environment = {
        systemPackages =
          with pkgs;
          [
            libpwquality
            cfg.packages.intune-portal
            cfg.packages.microsoft-identity-broker
            intuneRegisterDevice
          ]
          ++ lib.optionals cfg.vpn.enable [
            pkgs.gpauth
            pkgs.gpclient
            msftvpn
          ];

        # Register OpenSC as a p11-kit PKCS#11 module so that the identity
        # broker can discover smart-card credentials (e.g. Yubikey PIV) via
        # p11_kit_modules_load_and_initialize().
        etc."pkcs11/modules/opensc.module".text = ''
          module: ${pkgs.opensc}/lib/pkcs11/opensc-pkcs11.so
        '';

        # Route password changes through the PAM "passwd" service (which
        # enforces the corporate password policy below) instead of NixOS's
        # default "common-password" stack.
        etc."pam.d/common-password".source = "/etc/pam.d/passwd";

        sessionVariables.WEBKIT_DISABLE_DMABUF_RENDERER = "1";
      };

      # Keep PIV available to desktop applications without letting GDM switch
      # away from password authentication when a company smart card is inserted.
      programs.dconf.profiles.gdm.databases = [
        {
          settings."org/gnome/login-screen".enable-smartcard-authentication = false;
        }
      ];

      systemd = {
        sockets.intune-daemon = {
          description = "Intune daemon control socket";
          wantedBy = [ "sockets.target" ];
          socketConfig = {
            ListenStream = "/run/intune/daemon.socket";
            SocketMode = "0666";
          };
        };

        services = {
          intune-daemon = {
            description = "Intune daemon";
            requires = [ "intune-daemon.socket" ];
            serviceConfig = {
              ExecStart = "${cfg.packages.intune-portal}/bin/intune-daemon";
              ExecReload = "/bin/kill -HUP $MAINPID";
              StateDirectory = "intune";
              StateDirectoryMode = "0700";
              BindReadOnlyPaths = [ "${pkgs.fakeUbuntuOsRelease}:/etc/os-release" ];
            };
          };

          microsoft-identity-device-broker = {
            description = "Microsoft Identity Device Broker Service";
            serviceConfig = {
              Type = "dbus";
              BusName = "com.microsoft.identity.devicebroker1";
              ExecStart = "${cfg.packages.microsoft-identity-broker}/bin/microsoft-identity-device-broker";
              BindReadOnlyPaths = [ "${pkgs.fakeUbuntuOsRelease}:/etc/os-release" ];
            };
          };
        };

        user.services.intune-agent = {
          description = "Intune Agent";
          # Custom compliance discovery (Secure Boot + Microsoft UEFI CA 2023).
          path = with pkgs; [
            bash
            binutils
            dmidecode
            efitools
            gawk
            mokutil
            openssl
          ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${cfg.packages.intune-portal}/bin/intune-agent";
            StateDirectory = "intune";
            Slice = "background.slice";
          };
        };

        user.timers.intune-agent = {
          description = "Intune Agent scheduler";
          wantedBy = [ "graphical-session.target" ];
          partOf = [ "graphical-session.target" ];
          after = [ "graphical-session.target" ];
          unitConfig.DefaultDependencies = false;
          timerConfig = {
            AccuracySec = "2m";
            OnStartupSec = "5m";
            OnUnitActiveSec = "1h";
            RandomizedDelaySec = "10m";
          };
        };

        tmpfiles.rules = [
          "d /run/intune 0755 root root -"
          # The vendor package creates these in postinst; device join writes
          # the tenant certificate and private keys here.
          "d /etc/microsoft/identity-broker/private 0700 root root -"
          "d /etc/microsoft/identity-broker/certs 0700 root root -"
        ];
      };

      # Corporate password complexity policy for password changes.
      security.pam.services.passwd.rules.password.pwquality = {
        enable = true;
        control = "requisite";
        modulePath = "${pkgs.libpwquality}/lib/security/pam_pwquality.so";
        order = 10;
        settings = {
          retry = 3;
          minlen = 12;
          dcredit = -1;
          ucredit = -1;
          lcredit = -1;
          ocredit = -1;
        };
      };

      # Persist Intune daemon state and identity broker data, including the
      # device identity created during Entra join, across reboots/wipes.
      codgician.system.impermanence.extraItems =
        lib.optionals config.codgician.system.impermanence.enable
          [
            {
              path = "/var/lib/intune";
              type = "directory";
            }
            {
              path = "/var/lib/microsoft-identity-device-broker";
              type = "directory";
            }
            {
              path = "/etc/microsoft/identity-broker/private";
              type = "directory";
              mode = "0700";
            }
            {
              path = "/etc/microsoft/identity-broker/certs";
              type = "directory";
              mode = "0700";
            }
          ];

    }
    // (lib.codgician.mkServiceUserGroupLinux "microsoft-identity-broker" { })
  );
}
