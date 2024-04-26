{ config, lib, ... }:

with lib;

let
  cfg  = config.services.openssh;
in
{
  ###### interface
  options = {
    services.openssh = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to enable the OpenSSH secure shell daemon, which
          allows secure remote logins.
        '';
      };

      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Verbatim contents of {file}`/etc/ssh/sshd_config.d/200-nixos`.
        '';
      };
    };
  };

  ###### implementation
  config = mkIf cfg.enable {
    environment.etc."ssh/sshd_config.d/200-nixos".text = cfg.extraConfig;
  };
}
