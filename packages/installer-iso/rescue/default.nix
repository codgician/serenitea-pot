# Rescue tooling for the installer ISO. `rescue unlock <host>` mounts an
# installed host and adopts its SSH host key as the sops-nix identity, so
# secrets decrypt into RAM only after the user has unlocked that host's disks.
{
  # Attribute set of host name to ./host.nix output.
  hosts,
  # Flake revision the image was built from.
  revision,
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  rescue = pkgs.writeShellApplication {
    name = "rescue";
    runtimeInputs = [
      config.boot.zfs.package
      config.systemd.package
    ]
    ++ (with pkgs; [
      coreutils
      cryptsetup
      gawk
      jq
      kmod
      openssh
      util-linux
    ]);
    runtimeEnv.RESCUE_MANIFEST = pkgs.writeText "rescue-manifest.json" (
      builtins.toJSON {
        inherit hosts revision;
        inherit (pkgs.stdenv.hostPlatform) system;
      }
    );
    text = builtins.readFile ./rescue.sh;
  };

  completion = pkgs.writeTextDir "share/zsh/site-functions/_rescue" ''
    #compdef rescue
    _arguments -C '1:command:(unlock lock status)' '*::argument:->args'
    if [[ $state == args && $words[1] == unlock ]]; then
      _arguments '--rw[mount read-write]' '1:host:(${lib.concatStringsSep " " (builtins.attrNames hosts)})'
    fi
  '';
in
{
  environment.systemPackages = [
    rescue
    completion
  ];

  # Nothing decrypts at boot: `rescue unlock` links a verified host key here
  # and starts the unit itself.
  sops = {
    useSystemdActivation = true;
    age.sshKeyPaths = lib.mkForce [ "/run/rescue/ssh_host_ed25519_key" ];
  };
  systemd.services.sops-install-secrets = lib.mkIf (config.sops.secrets != { }) {
    wantedBy = lib.mkForce [ ];
    requiredBy = lib.mkForce [ ];
  };

  users.motd = ''
    Serenitea Pot installer and rescue (${revision})
      rescue unlock <host>   mount an installed host read-only (--rw to modify)
      rescue status          show what is mounted and unlocked
      rescue lock            unmount everything and wipe decrypted secrets
  '';
}
