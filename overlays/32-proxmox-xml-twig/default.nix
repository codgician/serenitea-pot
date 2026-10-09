# proxmox-nixos patches XML::Twig for a Perl 5.42 precedence warning, but
# nixpkgs now ships XML::Twig 3.54 which already contains that fix, so the
# patch no longer applies. Its package set closes over a private perl5, so
# rebuild it from `prev` with the perl overrides dropped.
# todo: remove when proxmox-nixos drops the XML::Twig patch

{ inputs, system, ... }:

_final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux (
  import "${inputs.proxmox-nixos}/pkgs" {
    pkgs = prev // {
      inherit (inputs.proxmox-nixos.inputs.nixpkgs-libvncserver.legacyPackages.${system}) libvncserver;
      perl5 = prev.perl5 // {
        override = args: prev.perl5.override (args // { overrides = _: { }; });
      };
    };
  }
)
