{ config, lib, ... }:
let
  cfg = config.codgician.services.coturn;
  inherit (lib) types;
  cert = config.security.acme.certs.${cfg.domain};
  listeningPort = 3478;
  tlsListeningPort = 5349;
  relayPortRange = {
    from = 49152;
    to = 65535;
  };
in
{
  options.codgician.services.coturn = {
    enable = lib.mkEnableOption "coturn STUN/TURN server";

    domain = lib.mkOption {
      type = types.str;
      default = "turn.codgician.me";
      description = "TURN realm and ACME certificate domain.";
      example = "turn.example.org";
    };

    listening-ips = lib.mkOption {
      type = types.listOf types.str;
      description = "Local listener addresses. Use wildcard addresses to listen on all interfaces.";
    };

    relay-ips = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Local addresses for relay sockets. If empty, coturn selects addresses automatically.";
    };

    external-ips = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "203.0.113.1/10.0.0.1" ];
      description = "Public/private address mappings for relay addresses behind port-preserving NAT.";
    };

    openFirewall = lib.mkEnableOption "opening the TURN listener and UDP relay ports";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.listening-ips != [ ];
        message = "coturn: listening-ips must contain at least one listener address.";
      }
    ];

    services.coturn = {
      enable = true;
      realm = cfg.domain;
      inherit (cfg) listening-ips relay-ips;
      listening-port = listeningPort;
      tls-listening-port = tlsListeningPort;
      min-port = relayPortRange.from;
      max-port = relayPortRange.to;
      use-auth-secret = true;
      static-auth-secret-file = config.codgician.secrets.files.coturn-auth-secret.path;
      cert = "${cert.directory}/fullchain.pem";
      pkey = "${cert.directory}/key.pem";
      # Coturn 4.16 disables the CLI and TLS versions below 1.2 by default.
      no-dtls = true;
      # WebRTC uses UDP relay allocations, including over TCP/TLS client connections.
      no-tcp-relay = true;
      extraConfig = ''
        ${lib.concatMapStringsSep "\n" (ip: "external-ip=${ip}") cfg.external-ips}
        no-rfc5780
        no-multicast-peers
        stale-nonce=600
        userdb=/run/coturn/turndb
        log-file=stdout
        simple-log
        # Prevent authenticated clients from reaching private networks and metadata services.
        denied-peer-ip=0.0.0.0-0.255.255.255
        denied-peer-ip=10.0.0.0-10.255.255.255
        denied-peer-ip=100.64.0.0-100.127.255.255
        denied-peer-ip=127.0.0.0-127.255.255.255
        denied-peer-ip=169.254.0.0-169.254.255.255
        denied-peer-ip=172.16.0.0-172.31.255.255
        denied-peer-ip=192.168.0.0-192.168.255.255
        denied-peer-ip=fc00::-fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
        denied-peer-ip=fe80::-febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff
      '';
    };

    codgician.secrets.files.coturn-auth-secret = {
      owner = "turnserver";
      group = "turnserver";
      mode = "0400";
    };

    codgician.acme.${cfg.domain} = {
      enable = true;
      reloadServices = [ "coturn.service" ];
    };

    systemd.services.coturn = {
      requires = [ "acme-${cfg.domain}.service" ];
      after = [ "acme-${cfg.domain}.service" ];
      serviceConfig.SupplementaryGroups = [ cert.group ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        listeningPort
        tlsListeningPort
      ];
      allowedUDPPorts = [ listeningPort ];
      allowedUDPPortRanges = [ relayPortRange ];
    };

    # TURN allocations and the unused REST-auth user database are ephemeral.
    # Upstream RuntimeDirectory creates /run/coturn and /run/turnserver;
    # no tmpfiles or service persistence is needed. ACME state is persisted centrally.
  };
}
