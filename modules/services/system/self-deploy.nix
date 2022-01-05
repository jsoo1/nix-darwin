{ config, lib, pkgs, ... }:

let
  cfg = config.services.self-deploy;

  launchd = import ../../launchd/launchd.nix { inherit lib; };

  darwinRebuild = lib.concatStringsSep " " [
    "${pkgs.nix-tools}/bin/darwin-rebuild"
    "--flake"
    cfg.flake
    "--no-write-lock-file"
    "--recreate-lock-file"
    cfg.switchCommand
    (lib.optionalString (!isNull cfg.logFile) "> ${cfg.logFile} 2>&1")
  ];

in
{
  options.services.self-deploy = {
    enable = lib.mkEnableOption "self-deploy";

    flake = lib.mkOption {
      type = lib.types.str;

      example = "github:example/foo/bar#baz.system";

      description = ''
        Flake uri that builds this nix-darwin configuration given to the
        `--flake` option of `darwin-rebuild`.
      '';
    };

    logFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;

      default = null;

      example = "/var/log/self-deploy.log";

      description = "Path to the log file for `self-deploy`.";
    };

    switchCommand = lib.mkOption {
      type = lib.types.enum [ "boot" "switch" "dry-activate" "test" ];

      default = "switch";

      description = ''
        The `darwin-rebuild` subcommand used.
      '';
    };

    interval = lib.mkOption {
      type = lib.types.str;

      default = "0 * * * *";

      example = "59 23 * * *";

      description = ''
        The interval on which `darwin-rebuild` should be run, in
        vixie-cron notation.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Avoid launchdaemon unloading before activation is complete.
    services.cron.enable = true;
    services.cron.systemCronJobs = [ "${cfg.interval} ${darwinRebuild}" ];
  };
}
