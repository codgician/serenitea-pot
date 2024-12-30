# Bump to latest prl-tools

{ lib, ... }:

self: super:{
  linuxPackages = super.linuxPackages.extend (lpself: lpsuper: {
    prl-tools = lpsuper.prl-tools.overrideAttrs rec {
      version = "20.1.3-55743";
      src = super.fetchurl {
        url = "https://download.parallels.com/desktop/v${lib.versions.major version}/${version}/ParallelsDesktop-${version}.dmg";
        hash = "sha256-5lbTTQucop/jnsVudoqTO9bESR5tdn8NFu9Nm2WphU4=";
      };
    };
  });
}
