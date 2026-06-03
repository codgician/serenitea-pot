{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.ssh;
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
        "*" = {
          addKeysToAgent = "yes";
        };
        "fischl" = {
          hostname = "fischl.lan";
          user = "codgi";
          ForwardAgent = true;
        };
        "focalors" = {
          hostname = "focalors.lan";
          user = "codgi";
          ForwardAgent = true;
        };
        "furina" = {
          hostname = "furina.lan";
          user = "codgi";
        };
        "lumine" = {
          hostname = "lumine.codgician.me";
          user = "codgi";
          ForwardAgent = true;
        };
        "lumidouce" = {
          hostname = "lumidouce.lan";
          user = "root";
        };
        "qiaoying" = {
          hostname = "qiaoying.cdu";
          user = "root";
        };
        "nahida" = {
          hostname = "nahida.lan";
          user = "codgi";
          ForwardAgent = true;
        };
        "paimon" = {
          hostname = "paimon.lan";
          user = "codgi";
          ForwardAgent = true;
        };
        "raiden-ei" = {
          hostname = "raiden-ei.lan";
          user = "codgi";
        };
        "sandrone" = {
          hostname = "sandrone.lan";
          user = "codgi";
          ForwardAgent = true;
        };
        "xianyun" = {
          hostname = "xianyun.codgician.me";
          user = "codgi";
          ForwardAgent = true;
        };
        "zibai" = {
          hostname = "zibai.cdu";
          user = "codgi";
          ForwardAgent = true;
        };
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
