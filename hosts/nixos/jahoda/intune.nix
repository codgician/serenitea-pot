# Microsoft Intune enrollment configuration with sandboxed Ubuntu identity
#
# This configuration spoofs Ubuntu 24.04 ONLY for Intune components while
# preserving the global NixOS identity. All Intune services see /etc/os-release
# as Ubuntu via systemd mount namespaces (BindReadOnlyPaths).
#
# Architecture:
#   Global NixOS: /etc/os-release = ID=nixos (unchanged)
#       │
#       ├── intune-daemon (system svc) → sees ID=ubuntu via BindReadOnlyPaths
#       ├── intune-agent (user svc) → sees ID=ubuntu via PrivateUsers + BindReadOnlyPaths
#       ├── microsoft-identity-broker → sees ID=ubuntu via sandboxing
#       └── intune-portal-wrapped (FHS) → sees ID=ubuntu via bubblewrap --ro-bind
#
{ pkgs, ... }:
let
  # Fake Ubuntu os-release for Intune sandboxing
  # This file is bind-mounted into Intune component namespaces
  fakeUbuntuOsRelease = pkgs.writeText "fake-os-release-ubuntu" ''
    NAME="Ubuntu"
    VERSION="24.04.2 LTS (Noble Numbat)"
    ID=ubuntu
    ID_LIKE=debian
    PRETTY_NAME="Ubuntu 24.04.2 LTS"
    VERSION_ID="24.04"
    VERSION_CODENAME=noble
    UBUNTU_CODENAME=noble
    HOME_URL="https://www.ubuntu.com/"
    SUPPORT_URL="https://help.ubuntu.com/"
    BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
  '';

  # FHS wrapper for intune-portal with sandboxed os-release
  # Uses bubblewrap to present fake /etc/os-release inside the sandbox
  intune-portal-wrapped = pkgs.buildFHSEnv {
    name = "intune-portal-wrapped";
    targetPkgs = pkgs: [ pkgs.intune-portal ];
    runScript = "intune-portal";
    extraBwrapArgs = [
      # Use --symlink to create /etc/os-release pointing to our fake file
      # (--ro-bind fails with "Can't create file" when destination doesn't exist)
      "--symlink"
      "${fakeUbuntuOsRelease}"
      "/etc/os-release"
    ];
    profile = ''
      # Disable DMA-BUF renderer to avoid GBM buffer creation failures on NVIDIA
      export WEBKIT_DISABLE_DMABUF_RENDERER=1
    '';
  };
in
{
  # Enable the NixOS Intune module (sets up systemd services, D-Bus, users)
  services.intune.enable = true;

  # Sandbox system services with fake os-release
  systemd.services.intune-daemon.serviceConfig.BindReadOnlyPaths = [
    "${fakeUbuntuOsRelease}:/etc/os-release"
  ];

  systemd.services.microsoft-identity-device-broker.serviceConfig.BindReadOnlyPaths = [
    "${fakeUbuntuOsRelease}:/etc/os-release"
  ];

  # Sandbox user services (requires PrivateUsers for mount namespace support)
  systemd.user.services.intune-agent.serviceConfig = {
    PrivateUsers = true;
    BindReadOnlyPaths = [ "${fakeUbuntuOsRelease}:/etc/os-release" ];
  };

  systemd.user.services.microsoft-identity-broker.serviceConfig = {
    PrivateUsers = true;
    BindReadOnlyPaths = [ "${fakeUbuntuOsRelease}:/etc/os-release" ];
  };

  # PAM password quality policy (required by Microsoft Intune compliance)
  # Settings: 12+ chars, at least 1 of each: uppercase, lowercase, digit, symbol
  environment.systemPackages = [ pkgs.libpwquality ];

  security.pam.services.passwd.rules.password.pwquality = {
    enable = true;
    control = "requisite";
    modulePath = "${pkgs.libpwquality}/lib/security/pam_pwquality.so";
    order = 10;
    settings = {
      retry = 3;
      minlen = 12;
      dcredit = -1; # At least 1 digit
      ucredit = -1; # At least 1 uppercase
      lcredit = -1; # At least 1 lowercase
      ocredit = -1; # At least 1 special char
    };
  };

  # Compatibility symlink for Intune PAM checks (expects Ubuntu-style path)
  environment.etc."pam.d/common-password".source = "/etc/pam.d/passwd";

  # Impermanence: persist Intune state across reboots
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

  # Home manager: add wrapped intune-portal and Edge browser
  home-manager.users.codgi.home.packages = [
    pkgs.microsoft-edge
    intune-portal-wrapped
  ];
}
