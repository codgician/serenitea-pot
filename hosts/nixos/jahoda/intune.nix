# Microsoft Intune with sandboxed Ubuntu identity (spoofs os-release for compliance)
{ pkgs, ... }:
{
  # Required for TLS support in WebKitGTK (used by Intune Portal authentication)
  services.gnome.glib-networking.enable = true;

  users.users.microsoft-identity-broker = {
    group = "microsoft-identity-broker";
    isSystemUser = true;
  };
  users.groups.microsoft-identity-broker = { };

  environment.systemPackages = with pkgs; [
    microsoft-identity-broker
    intune-portal
    libpwquality
  ];

  services.dbus.packages = [ pkgs.microsoft-identity-broker ];
  services.pcscd.enable = true;

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
          ExecStart = "${pkgs.intune-portal}/bin/intune-daemon";
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
          ExecStart = "${pkgs.microsoft-identity-broker}/bin/microsoft-identity-device-broker";
          BindReadOnlyPaths = [ "${pkgs.fakeUbuntuOsRelease}:/etc/os-release" ];
        };
      };
    };

    user.services.intune-agent = {
      description = "Intune Agent";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.intune-portal}/bin/intune-agent";
        StateDirectory = "intune";
        Slice = "background.slice";
      };
    };
  };

  systemd.tmpfiles.rules = [ "d /run/intune 0755 root root -" ];

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

  environment.etc."pam.d/common-password".source = "/etc/pam.d/passwd";
  environment.sessionVariables = {
    WEBKIT_DISABLE_DMABUF_RENDERER = "1";
  };

  codgician.system.impermanence.extraItems = [
    {
      path = "/var/lib/intune";
      type = "directory";
    }
    {
      path = "/var/lib/microsoft-identity-device-broker";
      type = "directory";
    }
  ];

  home-manager.users.codgi.home.packages = with pkgs; [
    microsoft-edge
    intune-portal
    azure-cli
    yubikey-manager
    yubico-piv-tool
  ];
}
