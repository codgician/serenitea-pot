# The NixOS agenix module is compatible with darwin
{ config, lib, pkgs, inputs, ... }:
import ../../nixos/system/agenix.nix { inherit config lib pkgs inputs; }
