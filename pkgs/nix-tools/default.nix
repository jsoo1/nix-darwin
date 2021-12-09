{ pkgs, ... }:

let
  darwin-option = pkgs.callPackage ./darwin-option.nix { };

  darwin-rebuild = pkgs.callPackage ./darwin-rebuild.nix { };
in

pkgs.symlinkJoin {
  name = "nix-tools";
  paths = [
    "${darwin-option}"
    "${darwin-rebuild}"
  ];
}
