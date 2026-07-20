{ ... }:

final: prev:
let
  fakeUbuntuOsRelease = prev.writeText "fake-os-release-ubuntu" ''
    NAME="Ubuntu"
    VERSION="24.04.4 LTS (Noble Numbat)"
    ID=ubuntu
    ID_LIKE=debian
    PRETTY_NAME="Ubuntu 24.04.4 LTS"
    VERSION_ID="24.04"
    VERSION_CODENAME=noble
    UBUNTU_CODENAME=noble
    HOME_URL="https://www.ubuntu.com/"
    SUPPORT_URL="https://help.ubuntu.com/"
    BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
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
