{ config, pkgs, lib, ... }:

let
  users = config.users.users;

  etcAuthorizedKeysDir = pkgs.runCommandLocal "authorized_keys.d" { } ''
    mkdir $out
    ${lib.concatStringsSep "\n" userEtcFiles}
  '';

  userEtcFiles = builtins.attrValues (lib.mapAttrs mkUserAuthorizedKeys
    (lib.filterAttrs (_: hasAuthorizedKeys) users));

  hasAuthorizedKeys = user:
    user ? openssh
    && user.openssh ? authorizedKeys
    && user.openssh.authorizedKeys ? keyFiles
    && user.openssh.authorizedKeys.keyFiles != { };

  mkUserAuthorizedKeys = name: user:
    let
      mkStoreKeyFile = path: "${builtins.path { inherit path; }}";

      keys = builtins.map mkStoreKeyFile user.openssh.authorizedKeys.keyFiles;
    in
    ''
      cat ${lib.concatStringsSep " " keys} > "$out/${name}"
      chmod 444 "$out/${name}"
    '';
in

{
  config = {
    environment.etc."ssh/sshd_config.d/200-nixos".text =
      lib.mkIf (builtins.any hasAuthorizedKeys (builtins.attrValues users))
        "AuthorizedKeysFile .ssh/authorized_keys /etc/ssh/authorized_keys.d/%u";

    system.activationScripts.extraActivation.text = lib.mkMerge [
      ''
        rm -rf /etc/ssh/authorized_keys.d > /dev/null 2>&1 || true
      ''
      (lib.mkIf (builtins.any hasAuthorizedKeys (builtins.attrValues users)) ''
        mkdir -p /etc/ssh/authorized_keys.d
        cp ${etcAuthorizedKeysDir}/* /etc/ssh/authorized_keys.d
      '')
    ];
  };
}
