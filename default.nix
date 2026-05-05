{ pkgs ? import <nixpkgs> {}, ... }: (import ./flake.nix).outputs {
  self = builtins.path { path = ./.; };
  inherit pkgs;
}
