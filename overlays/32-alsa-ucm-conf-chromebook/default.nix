{ ... }:

_: prev: {
  alsa-ucm-conf-chromebook = prev.stdenvNoCC.mkDerivation {
    pname = "alsa-ucm-conf-chromebook";
    version = "a46dd193";

    src = prev.fetchFromGitHub {
      owner = "WeirdTreeThing";
      repo = "alsa-ucm-conf-cros";
      rev = "a46dd193ab81ed71c4465453f5297f21e413769f";
      hash = "sha256-eARLyVzMI84SRNkts8l9jjloWfnZ5gH+0EhFxNa0EY4=";
    };

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/alsa
      cp -rL ${prev.alsa-ucm-conf}/share/alsa/. $out/share/alsa/
      chmod -R u+w $out/share/alsa
      cp -r ucm2/. $out/share/alsa/ucm2/
      cp -r overrides/. $out/share/alsa/ucm2/conf.d/

      runHook postInstall
    '';
  };
}
