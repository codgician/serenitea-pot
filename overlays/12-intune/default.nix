{ ... }:

final: prev:
{
  intune-portal = prev.unstable.intune-portal.overrideAttrs (_: rec {
    version = "1.2603.31-noble";
    src = prev.fetchurl {
      url = "https://packages.microsoft.com/ubuntu/24.04/prod/pool/main/i/intune-portal/intune-portal_${version}_amd64.deb";
      hash = "sha256-0braaXnRa04CUQdJx0ZFwe5qfjsJNzTtGqaKQV5Z6Yw=";
    };
  });

  microsoft-identity-broker = prev.unstable.microsoft-identity-broker.overrideAttrs (_: rec {
    version = "2.5.2";
    src = prev.fetchurl {
      url = "https://packages.microsoft.com/ubuntu/24.04/prod/pool/main/m/microsoft-identity-broker/microsoft-identity-broker_${version}-noble_amd64.deb";
      hash = "sha256-t5XP85ar16Et3fIp+Ia5KlD9fYwzbxHlcUlliseVTIk=";
    };
  });
}