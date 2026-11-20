# Each folder gives `checks` and, for VM tests run on demand, `vmTests`.
args@{ lib, ... }:

let
  tests = map (name: import ./${name} args) (lib.codgician.getFolderNames ./.);
in
{
  checks = lib.mergeAttrsList (map (test: test.checks or { }) tests);
  vmTests = lib.mergeAttrsList (map (test: test.vmTests or { }) tests);
}
