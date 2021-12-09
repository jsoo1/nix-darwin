{ pkgs, nix-darwin, ... }:

{
  darwin-installer = pkgs.callPackage ./darwin-installer { inherit nix-darwin; };
  darwin-uninstaller = pkgs.callPackage ./darwin-uninstaller { inherit nix-darwin; };
  nix-tools = pkgs.callPackage ./nix-tools { };
}
