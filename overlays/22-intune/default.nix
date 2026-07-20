{ ... }:

final: prev:
let
  fakeUbuntuOsRelease = prev.writeText "fake-os-release-ubuntu" ''
    PRETTY_NAME="Ubuntu 26.04 LTS"
    NAME="Ubuntu"
    VERSION_ID="26.04"
    VERSION="26.04 (Resolute Raccoon)"
    VERSION_CODENAME=resolute
    ID=ubuntu
    ID_LIKE=debian
    HOME_URL="https://www.ubuntu.com/"
    SUPPORT_URL="https://help.ubuntu.com/"
    BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
    PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
    UBUNTU_CODENAME=resolute
    LOGO=ubuntu-logo
  '';

  intune-portal-unwrapped = prev.nur.repos.codgician.intune-portal;

  mkBwrapWrapper =
    name:
    prev.writeShellScript "${name}-wrapper" ''
      OS_RELEASE_TARGET=$(${prev.coreutils}/bin/readlink -f /etc/os-release)
      exec ${prev.bubblewrap}/bin/bwrap \
        --bind / / \
        --ro-bind ${fakeUbuntuOsRelease} "$OS_RELEASE_TARGET" \
        --dev-bind /dev /dev \
        --proc /proc \
        --die-with-parent \
        -- ${intune-portal-unwrapped}/bin/${name} "$@"
    '';

  desktopItem = prev.makeDesktopItem {
    name = "intune-portal";
    desktopName = "Microsoft Intune";
    comment = "Microsoft Intune";
    exec = "env INTUNE_NO_LOG_STDOUT=1 intune-portal";
    icon = "intune";
    terminal = false;
  };
in
{
  intune-portal = prev.symlinkJoin {
    name = "intune-portal-${intune-portal-unwrapped.version}";
    paths = [ intune-portal-unwrapped ];
    postBuild = ''
      rm $out/bin/intune-portal $out/bin/intune-agent
      ln -s ${mkBwrapWrapper "intune-portal"} $out/bin/intune-portal
      ln -s ${mkBwrapWrapper "intune-agent"} $out/bin/intune-agent

      # Replace .desktop with version pointing to wrapped binary
      rm $out/share/applications/intune-portal.desktop
      ln -s ${desktopItem}/share/applications/intune-portal.desktop $out/share/applications/intune-portal.desktop
    '';
  };

  inherit intune-portal-unwrapped fakeUbuntuOsRelease;

  microsoft-identity-broker = prev.unstable.microsoft-identity-broker;
}
