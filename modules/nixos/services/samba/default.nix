{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.samba;
  userCfg = config.codgician.users;
  types = lib.types;
in
{
  options.codgician.services.samba = {
    enable = lib.mkEnableOption "Samba server.";

    users = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of users that has access to samba file shares.
      '';
    };

    shares = lib.mkOption {
      type = types.attrsOf (types.attrsOf types.unspecified);
      default = { };
      description = ''
        A set describing shared resources. Passes through to `services.samba.shares`.
        See {command}`man smb.conf` for options.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Samba configurations
    services.samba = {
      enable = true;
      package = pkgs.sambaFull;
      openFirewall = true;

      nsswins = true;
      smbd.enable = true;
      nmbd.enable = true;
      winbindd.enable = true;

      settings = cfg.shares // {
        global = {
          "protocol" = "SMB3";
          "min protocol" = "SMB3";
          "server string" = config.networking.hostName;
          "netbios name" = config.networking.hostName;
          "wins support" = "yes";
          "invalid users" = [ "root" ];
          "security" = "user";
          "server smb encrypt" = "desired";

          "vfs objects" = "acl_xattr catia fruit streams_xattr aio_pthread";
          "aio read size" = "16384";
          "aio write size" = "16384";

          "fruit:aapl" = "yes";
          "fruit:model" = "MacSamba";
          "fruit:posix_rename" = "yes";
          "fruit:metadata" = "stream";
          "fruit:nfs_aces" = "no";
          "fruit:copyfile" = "yes";
          "fruit:veto_appledouble" = "no";
          "fruit:wipe_intentionally_left_blank_rfork" = "yes";
          "fruit:delete_empty_adfiles" = "yes";
          "fruit:zero_file_id" = "yes";
        };
      };
    };

    # Make shares visible to Windows clients
    services.samba-wsdd = {
      enable = true;
      openFirewall = true;
      hostname = config.networking.hostName;
    };

    # Make sure user passwords are updated
    systemd.services.samba-smbd.serviceConfig.ExecStartPre = lib.getExe (
      pkgs.writeShellApplication {
        name = "samba-password-refresh";
        text =
          let
            mkCommand =
              user:
              let
                passwordFile =
                  config.age.secrets."${lib.codgician.getAgeSecretNameFromPath userCfg.${user}.passwordAgeFile}".path;
              in
              ''
                echo "Refreshing samba password for: ${user}"
                (cat ${passwordFile}; cat ${passwordFile};) | ${config.services.samba.package}/bin/smbpasswd -s -a "${user}"
              '';
          in
          lib.pipe cfg.users [
            (builtins.map mkCommand)
            (builtins.concatStringsSep "\n")
          ];
      }
    );

    # Persist data
    codgician.system.impermanence.extraItems = [
      {
        type = "directory";
        path = "/var/lib/samba";
      }
    ];

    # Assertions
    assertions =
      let
        mkUserAssertion = user: {
          assertion = userCfg ? ${user} && userCfg.${user}.passwordAgeFile != null;
          message = ''
            User "${user}" must have plain password file configured when samba is enabled.
          '';
        };
      in
      builtins.map mkUserAssertion cfg.users;
  };
}
