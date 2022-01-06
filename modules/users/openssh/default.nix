{ config, pkgs, lib, ... }:

let
  users = config.users.users;

  etcAuthorizedKeysDir = pkgs.runCommandLocal "authorized_keys.d" { } ''
    mkdir $out
    ${lib.concatStringsSep "\n" userEtcFiles}
  '';

  userEtcFiles = builtins.attrValues (lib.mapAttrs mkUserEtcFiles
    (lib.filterAttrs (_: hasAuthorizedKeys) users));

  mkUserEtcFiles = name: user:
    mkUserAuthorizedKeys name user.openssh.authorizedKeys.keyFiles;

  hasAuthorizedKeys = user:
    user ? openssh
    && user.openssh ? authorizedKeys
    && user.openssh.authorizedKeys ? keyFiles
    && user.openssh.authorizedKeys.keyFiles != { };

  mkUserAuthorizedKeys = userName: keyFiles:
    let
      mkStoreKeyFile = path: ''"${builtins.path { inherit path; }}"'';

      keys = builtins.map mkStoreKeyFile keyFiles;
    in
    ''
      cat ${lib.concatStringsSep " " keys} > "$out/${userName}"
      chmod 444 "$out/${userName}"
    '';
in

{
  config = {
    environment.etc."ssh/sshd_config.d/200-nixos".text =
      lib.mkIf (builtins.any hasAuthorizedKeys (builtins.attrValues users))
        "AuthorizedKeysFile .ssh/authorized_keys /etc/ssh/authorized_keys.d/%u";

    system.activationScripts.extraActivation.text = ''
      rm -rf /etc/ssh/authorized_keys.d > /dev/null 2>&1 || true
      ${lib.optionalString (builtins.any hasAuthorizedKeys (builtins.attrValues users)) ''
        mkdir -p /etc/ssh/authorized_keys.d
        cp ${etcAuthorizedKeysDir}/* /etc/ssh/authorized_keys.d
      ''}
    '';
  };
}
