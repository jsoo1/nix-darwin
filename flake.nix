{
  # WARNING this is very much still experimental.
  description = "A collection of darwin modules";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils, nixpkgs }:
    let
      darwinSystems =
        builtins.filter
          (sys: builtins.isList (builtins.match "^[[:alnum:]_]+-darwin$" sys))
          flake-utils.lib.allSystems;

      portable = flake-utils.lib.eachSystem darwinSystems
        (system:
          let pkgs = import nixpkgs { inherit system; };

          in rec {
            packages = pkgs.callPackage ./pkgs { nix-darwin = self; };

            defaultApp = apps.darwin-installer;

            apps = {
              darwin-installer = flake-utils.lib.mkApp {
                drv = packages.darwin-installer;
              };

              darwin-uninstaller = flake-utils.lib.mkApp {
                drv = packages.darwin-uninstaller;
              };

              darwin-option = {
                type = "app";
                program = "${packages.nix-tools}/bin/darwin-option";
              };

              darwin-rebuild = {
                type = "app";
                program = "${packages.nix-tools}/bin/darwin-rebuild";
              };
            };

            checks.simple = (self.lib.darwinSystem {
              inherit system;
              modules = [ self.darwinModules.simple ];
            }).system;
          });

    in {
    inherit (portable) defaultApp apps packages checks;

    lib = {
      # TODO handle multiple architectures.
      evalConfig = import ./eval-config.nix { inherit (nixpkgs) lib; };

      darwinSystem =
        { modules, inputs ? { }
        , system ? throw "darwin.lib.darwinSystem now requires 'system' to be passed explicitly"
        , ...
        }@args:
        self.lib.evalConfig (args // {
          inherit system;
          inputs = { inherit nixpkgs; darwin = self; } // inputs;
          modules = modules ++ [ self.darwinModules.flakeOverrides ];
        });
    };

    darwinModules.flakeOverrides = ./modules/system/flake-overrides.nix;
    darwinModules.hydra = ./modules/examples/hydra.nix;
    darwinModules.lnl = ./modules/examples/lnl.nix;
    darwinModules.ofborg = ./modules/examples/ofborg.nix;
    darwinModules.simple = ./modules/examples/simple.nix;

  };
}
