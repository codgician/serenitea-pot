{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.intune;
  inherit (pkgs) mdatp;

  installDir = "/opt/microsoft/mdatp";
  stateDir = "/var/opt/microsoft/mdatp";
  configDir = "/etc/opt/microsoft/mdatp";
  logDir = "/var/log/microsoft/mdatp";
  onboardingSecret = config.codgician.secrets.files."mdatp-onboard".path;

  fhs = "${mdatp}/libexec/mdatp/fhs";

  # Mirror the vendor units (start in sbin), record the daemon's PID, and
  # re-target socket activation at the daemon, which runs below bubblewrap.
  launch = pkgs.writeShellScript "mdatp-launch" ''
    pidFile=$1
    shift
    cd ${installDir}/sbin
    if [ -n "''${LISTEN_FDS:-}" ]; then
      export LISTEN_PID=$$
      # Identifies the start script's pidfd; libsystemd rejects a mismatch.
      unset LISTEN_PIDFDID
    fi
    echo $$ > "$pidFile"
    exec "$@"
  '';

  # In the vendor units the daemon is the main process, so stopping the unit
  # signals it directly; under bubblewrap it is not (and wdavdaemon moves to
  # its own /mde cgroup, out of reach of the unit's kill). Run the sandbox as
  # a forking service whose PID file names the daemon, so systemd supervises
  # and signals the daemon itself.
  mkStart =
    name:
    pkgs.writeShellScript "${name}-start" ''
      pidFile=$RUNTIME_DIRECTORY/main.pid
      rm -f "$pidFile"
      ${fhs} ${launch} "$pidFile" ${installDir}/sbin/${name} &
      while [ ! -s "$pidFile" ]; do
        kill -0 $! 2>/dev/null || exit 1
        ${pkgs.coreutils}/bin/sleep 0.1
      done
    '';

  # The parts of the vendor postinst the daemon depends on: machine identity
  # and release ring in wdavstate, the bundled definitions database, and the
  # onboarding blob that the onboarding script would copy into place.
  prepare = pkgs.writeShellScript "mdatp-prepare" ''
    set -euo pipefail

    json=${installDir}/sbin/install_helper
    state=${stateDir}/wdavstate
    definitionsRoot=${stateDir}/definitions.noindex
    bundledDefinitions=$definitionsRoot/00000000-0000-0000-0000-000000000000
    bundledStamp=${stateDir}/.nixos-bundled-definitions
    uuidPattern='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

    get() { "$json" get-json --file "$state" --field "$1" 2>/dev/null || true; }
    set_() { "$json" set-json --file "$state" --field "$1" --type "$2" --value "$3"; }

    mkdir -p ${stateDir}/crash
    chmod 755 ${stateDir}/..

    dmiUuid=$(tr '[:upper:]' '[:lower:]' < /sys/class/dmi/id/product_uuid 2>/dev/null || true)
    [[ $dmiUuid =~ $uuidPattern ]] || dmiUuid=

    machineGuid=$(get machineGuid)
    if [[ -z $machineGuid || $machineGuid == null ]]; then
      if [[ -n $dmiUuid ]]; then
        set_ machineGuid string "$dmiUuid"
        set_ machineUuidType string Dmid
      else
        set_ machineGuid string "$(cat /proc/sys/kernel/random/uuid)"
        set_ machineUuidType string Uuid
      fi
      set_ validateId bool true
    fi
    set_ releaseRing string Production
    if [[ -n $dmiUuid ]]; then
      set_ platformDmidecodeUuid string "$dmiUuid"
    fi

    if [[ $(cat "$bundledStamp" 2>/dev/null) != ${mdatp.unwrapped} ]]; then
      rm -rf "$bundledDefinitions"
      mkdir -p "$bundledDefinitions"
      install -m 444 -t "$bundledDefinitions" ${installDir}/definitions/*
      echo ${mdatp.unwrapped} > "$bundledStamp"
    fi
    if [[ -z $(get engineCore.databaseRootPath) ]]; then
      set_ engineCore.databaseRootPath string "$definitionsRoot"
      set_ engineCore.activeDatabasePath string "$bundledDefinitions"
    fi
    chmod 600 "$state"

    if ! cmp -s ${onboardingSecret} ${configDir}/mdatp_onboard.json; then
      install -m 600 ${onboardingSecret} ${configDir}/mdatp_onboard.json
    fi
  '';

  vendorEnvironment = {
    LD_LIBRARY_PATH = "${installDir}/lib/";
    LD_PRELOAD = "";
    LD_AUDIT = "";
  };
in
{
  options.codgician.services.intune.mdatp = {
    enable = lib.mkEnableOption "Microsoft Defender for Endpoint (mdatp), onboarded to the Intune tenant";
  };

  config = lib.mkIf (cfg.enable && cfg.mdatp.enable) (
    {
      environment.systemPackages = [ mdatp ];

      codgician.secrets.files."mdatp-onboard" = { };

      systemd = {
        services = {
          mdatp = {
            description = "Microsoft Defender";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            environment = vendorEnvironment // {
              MALLOC_ARENA_MAX = "2";
              ENABLE_CRASHPAD = "1";
            };
            startLimitIntervalSec = 120;
            startLimitBurst = 3;
            serviceConfig = {
              Type = "forking";
              RuntimeDirectory = "mdatp";
              PIDFile = "/run/mdatp/main.pid";
              ExecStartPre = "${fhs} ${prepare}";
              ExecStart = mkStart "wdavdaemon";
              NotifyAccess = "main";
              LimitNOFILE = 65536;
              Restart = "always";
              RestartSec = 5;
              Delegate = true;
            };
          };

          mde_netfilter_v2 = {
            description = "Microsoft Defender Netfilter Platform";
            after = [
              "network.target"
              "local-fs.target"
            ];
            requires = [ "mde_netfilter_v2.socket" ];
            environment = vendorEnvironment;
            startLimitIntervalSec = 120;
            startLimitBurst = 3;
            serviceConfig = {
              Type = "forking";
              RuntimeDirectory = "mde_netfilter_v2";
              PIDFile = "/run/mde_netfilter_v2/main.pid";
              ExecStart = mkStart "mde_netfilter";
              NotifyAccess = "main";
              LimitCORE = "infinity";
              KillMode = "process";
              Restart = "on-failure";
              PrivateTmp = true;
              NoNewPrivileges = true;
              PrivateDevices = true;
            };
          };
        };

        sockets.mde_netfilter_v2 = {
          description = "Microsoft Defender Netfilter Activation Socket";
          wantedBy = [ "sockets.target" ];
          socketConfig = {
            ListenStream = "/run/mde_netfilter.sock";
            SocketMode = "0600";
          };
        };

        tmpfiles.rules = [
          "d ${configDir} 0755 root root -"
          "d ${stateDir} 0755 root root -"
          "d ${logDir} 0775 root mdatp -"
        ];
      };

      codgician.system.impermanence.extraItems =
        lib.optionals config.codgician.system.impermanence.enable
          [
            # The daemon's unprivileged (mdatp) workers traverse these.
            {
              path = configDir;
              type = "directory";
              mode = "0755";
            }
            {
              path = stateDir;
              type = "directory";
              mode = "0755";
            }
            {
              path = logDir;
              type = "directory";
              group = "mdatp";
              mode = "0775";
            }
          ];
    }
    // (lib.codgician.mkServiceUserGroupLinux "mdatp" { })
  );
}
