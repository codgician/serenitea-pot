{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.ssh;
  # Host name -> domain suffix.
  mkHosts = attrs: lib.mapAttrs (name: domain: { hostname = "${name}.${domain}"; } // attrs);
  trusted = {
    user = "codgi";
    ForwardAgent = true;
  };
in
{
  options.codgician.codgi.ssh.enable = lib.mkEnableOption "Ssh user configurations.";

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      extraConfig = ''
        IdentityFile ~/.ssh/id_ed25519
      ''
      + lib.optionalString pkgs.stdenvNoCC.isDarwin ''
        IgnoreUnknown UseKeychain
        UseKeychain yes
      '';
      settings = {
        "*".addKeysToAgent = "yes";
      }
      # Hosts the inventory calls public are reached at their public name.
      // lib.mapAttrs (_: host: { hostname = host.domain; } // trusted) (
        lib.filterAttrs (_: host: host.public) lib.codgician.published.hosts
      )
      // mkHosts trusted {
        fischl = "lan";
        focalors = "lan";
        nahida = "lan";
        paimon = "lan";
        sandrone = "lan";
        zibai = "cdu";
      }
      // mkHosts { user = "codgi"; } {
        furina = "lan";
        odette = "lan";
        raiden-ei = "lan";
      }
      // mkHosts { user = "root"; } {
        lumidouce = "lan";
        qiaoying = "cdu";
      };
    };

    # macOS: load any SSH keys already saved to the login Keychain at
    # activation time, so the native ssh-agent has them without a prompt.
    # First-ever save still happens on first interactive use (or once via
    # `ssh-add --apple-use-keychain ~/.ssh/id_ed25519`). Idempotent.
    home.activation.sshLoadKeychain = lib.mkIf pkgs.stdenvNoCC.isDarwin (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -f "$HOME/.ssh/id_ed25519" ]; then
          run /usr/bin/ssh-add --apple-load-keychain 2>/dev/null || true
        fi
      ''
    );
  };
}
