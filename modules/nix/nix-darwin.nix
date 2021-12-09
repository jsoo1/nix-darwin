{ pkgs, nix-darwin, ... }:

let
  nix-tools = pkgs.callPackage ../../pkgs/nix-tools {
    inherit nix-darwin;
  };
in

{
  # Include nix-tools by default
  environment.systemPackages = [ nix-tools ];
}
