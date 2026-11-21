# Which secrets and templates the secrets module deploys for a set of host
# identities, and where a secret needed before users exist lands. Decryption
# itself is sops-nix's.
{ lib, pkgs, ... }:
let
  fixtures = ./fixtures;

  node = lib.codgician.mkNixosSystem {
    hostName = "secrets";
    inherit (pkgs.stdenv.hostPlatform) system;
    modules = [
      (
        { config, ... }:
        {
          boot.loader.grub.device = "nodev";
          fileSystems."/" = {
            device = "/dev/vda";
            fsType = "ext4";
          };
          system.stateVersion = "26.05";

          # Only what both may decrypt is deployed.
          codgician.secrets.hosts = [
            "jahoda"
            "lumine"
          ];

          codgician.secrets.files.test-password = {
            sopsFile = fixtures + "/test-password";
            format = "binary";
            neededForUsers = true;
          };
          users.users.loginuser = {
            isNormalUser = true;
            hashedPasswordFile = config.codgician.secrets.files.test-password.path;
          };
          # The owner of the templates
          users.users.codgi.isNormalUser = true;
        }
      )
    ];
  };
  inherit (node) config;

  rejected =
    module:
    map (check: check.message) (
      lib.filter (check: !check.assertion && lib.hasPrefix "codgician.secrets" check.message)
        (node.extendModules { modules = [ module ]; }).config.assertions
    );

  expectations = {
    "secrets of jahoda and lumine" = {
      actual = lib.genAttrs [
        "sing-codgi-ss-password"
        "anubis-ed25519-private-key-hex"
        "mdatp-onboard"
      ] (name: config.codgician.secrets.files ? ${name});
      expected = {
        sing-codgi-ss-password = true;
        anubis-ed25519-private-key-hex = false;
        mdatp-onboard = false;
      };
    };

    "templates of jahoda and lumine" = {
      actual = lib.genAttrs [
        "sing-codgi-ss-client-password"
        "sing-itscd-ss-client-password"
        "anubis-env"
      ] (name: config.sops.templates ? ${name});
      expected = {
        sing-codgi-ss-client-password = true;
        sing-itscd-ss-client-password = false;
        anubis-env = false;
      };
    };

    "a secret needed before users exist" = {
      actual = {
        inherit (config.sops.secrets.test-password) neededForUsers;
        hashedPasswordFile = config.users.users.loginuser.hashedPasswordFile;
      };
      expected = {
        neededForUsers = true;
        hashedPasswordFile = "/run/secrets-for-users/test-password";
      };
    };

    "what the secrets module rejects" = {
      actual = rejected {
        users.users.testsvc = {
          isSystemUser = true;
          group = "testsvc";
        };
        users.groups.testsvc = { };
        codgician.secrets.files.test-password.owner = "testsvc";
      };
      expected = [
        "codgician.secrets.files.test-password: neededForUsers requires root:root ownership."
      ];
    };
  };

  failures = lib.filterAttrs (_: e: e.actual != e.expected) expectations;
in
{
  checks.secretsDeployed =
    assert lib.assertMsg (failures == { }) "secrets: ${builtins.toJSON failures}";
    pkgs.runCommand "secrets-deployed" { } "touch $out";
}
