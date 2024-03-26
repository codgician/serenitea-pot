{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.services.samba;
  userCfg = config.codgician.users;
  types = lib.types;
  getAgeSecretNameFromPath = path: lib.removeSuffix ".age" (builtins.baseNameOf path);
in
{
  options.codgician.services.samba = {
    enable = lib.mkEnableOption "Enable samba server.";

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

      securityType = "user";
      enableNmbd = true;
      openFirewall = true;

      invalidUsers = [ "root" ];

      extraConfig = ''
        server string = ${config.networking.hostName}
        netbios name = ${config.networking.hostName}

        #server signing = mandatory
        server min protocol = NT1
        #server smb encrypt = required
      '';

      shares = cfg.shares;
    };

    # Make shares visible to Windows clients
    services.samba-wsdd.enable = true;

    # Make sure user passwords are updated
    system.activationScripts.sambaPasswordRefresh = {
      supportsDryActivation = false;
      text =
        let
          sambaPkg = config.services.samba.package;
          sambaUsersString = builtins.concatStringsSep "," cfg.users;
          mkCommand = user:
            let passwordFile = config.age.secrets."${getAgeSecretNameFromPath userCfg.${user}.passwordAgeFile}".path;
            in ''(cat ${passwordFile}; cat ${passwordFile};) | ${sambaPkg}/bin/smbpasswd -s -a "${user}"'';
          commands = [
            ''echo -e "refreshing samba password for: ${sambaUsersString}"''
          ] ++ builtins.map mkCommand cfg.users;
          script = builtins.concatStringsSep "; " commands;
        in
        "${pkgs.sudo}/bin/sudo ${pkgs.bash}/bin/bash -c '${script}'";
    };

    # Assertions
    assertions =
      let
        mkUserAssertion = user: {
          assertion = userCfg?${user} && userCfg.${user}.passwordAgeFile != null;
          message = ''
            User "${user}" must have plain password file configured when samba is enabled.
          '';
        };
      in
      builtins.map mkUserAssertion cfg.users;
  };
}
