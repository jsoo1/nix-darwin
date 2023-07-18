{ config, lib, ... }:

with lib;

let
  cfg  = config.programs.ssh;

  knownHosts = map (h: getAttr h cfg.knownHosts) (attrNames cfg.knownHosts);

  knownHostsFiles = [ "/etc/ssh/ssh_known_hosts" "/etc/ssh/ssh_known_hosts2" ]
    ++ map pkgs.copyPathToStore cfg.knownHostsFiles;

  host =
    { name, config, ... }:
    {
      options = {
        hostNames = mkOption {
          type = types.listOf types.str;
          default = [];
          description = lib.mdDoc ''
            A list of host names and/or IP numbers used for accessing
            the host's ssh service.
          '';
        };
        extraHostNames = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            A list of additional host names and/or IP numbers used for
            accessing the host's ssh service. This list is ignored if
            `hostNames` is set explicitly.
          '';
        };
        publicKey = mkOption {
          default = null;
          type = types.nullOr types.str;
          example = "ecdsa-sha2-nistp521 AAAAE2VjZHN...UEPg==";
          description = lib.mdDoc ''
            The public key data for the host. You can fetch a public key
            from a running SSH server with the {command}`ssh-keyscan`
            command. The public key should not include any host names, only
            the key type and the key itself.
          '';
        };
        publicKeyFile = mkOption {
          default = null;
          type = types.nullOr types.path;
          description = lib.mdDoc ''
            The path to the public key file for the host. The public
            key file is read at build time and saved in the Nix store.
            You can fetch a public key file from a running SSH server
            with the {command}`ssh-keyscan` command. The content
            of the file should follow the same format as described for
            the `publicKey` option.
          '';
        };
      };
      config = {
        hostNames = mkDefault ([ name ] ++ config.extraHostNames);
      };
    };
  # Taken from: https://github.com/NixOS/nixpkgs/blob/f4aa6afa5f934ece2d1eb3157e392d056be01617/nixos/modules/services/networking/ssh/sshd.nix#L46-L93
  userOptions = {

    options.openssh.authorizedKeys = {
      keys = mkOption {
        type = types.listOf types.str;
        default = [];
        description = lib.mdDoc ''
          A list of verbatim OpenSSH public keys that should be added to the
          user's authorized keys. The keys are added to a file that the SSH
          daemon reads in addition to the the user's authorized_keys file.
          You can combine the `keys` and
          `keyFiles` options.
          Warning: If you are using `NixOps` then don't use this
          option since it will replace the key required for deployment via ssh.
        '';
      };

      keyFiles = mkOption {
        type = types.listOf types.path;
        default = [];
        description = lib.mdDoc ''
          A list of files each containing one OpenSSH public key that should be
          added to the user's authorized keys. The contents of the files are
          read at build time and added to a file that the SSH daemon reads in
          addition to the the user's authorized_keys file. You can combine the
          `keyFiles` and `keys` options.
        '';
      };
    };

  };

  authKeysFiles = let
    mkAuthKeyFile = u: nameValuePair "ssh/authorized_keys.d/${u.name}" {
      copy = true;
      text = ''
        ${concatStringsSep "\n" u.openssh.authorizedKeys.keys}
        ${concatMapStrings (f: readFile f + "\n") u.openssh.authorizedKeys.keyFiles}
      '';
    };
    usersWithKeys = attrValues (flip filterAttrs config.users.users (n: u:
      length u.openssh.authorizedKeys.keys != 0 || length u.openssh.authorizedKeys.keyFiles != 0
    ));
  in listToAttrs (map mkAuthKeyFile usersWithKeys);

  oldAuthorizedKeysHash = "5a5dc1e20e8abc162ad1cc0259bfd1dbb77981013d87625f97d9bd215175fc0a";
in

{
  options = {

    users.users = mkOption {
      type = with types; attrsOf (submodule userOptions);
    };

    services.openssh.authorizedKeysFiles = mkOption {
      type = types.listOf types.str;
      default = [];
      description = lib.mdDoc ''
        Specify the rules for which files to read on the host.

        This is an advanced option. If you're looking to configure user
        keys, you can generally use [](#opt-users.users._name_.openssh.authorizedKeys.keys)
        or [](#opt-users.users._name_.openssh.authorizedKeys.keyFiles).

        These are paths relative to the host root file system or home
        directories and they are subject to certain token expansion rules.
        See AuthorizedKeysFile in man sshd_config for details.
      '';
    };

    programs.ssh.knownHostsFiles = mkOption {
      default = [];
      type = with types; listOf path;
      description = ''
        Files containing SSH host keys to set as global known hosts.
        <literal>/etc/ssh/ssh_known_hosts</literal> (which is
        generated by <option>programs.ssh.knownHosts</option>) and
        <literal>/etc/ssh/ssh_known_hosts2</literal> are always
        included.
      '';
      example = literalExpression ''
        [
          ./known_hosts
          (writeText "github.keys" '''
            github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
            github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
            github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
          ''')
        ]
      '';
    };

    programs.ssh.knownHosts = mkOption {
      default = {};
      type = types.attrsOf (types.submodule host);
      description = lib.mdDoc ''
        The set of system-wide known SSH hosts.
      '';
      example = literalExpression ''
        [
          {
            hostNames = [ "myhost" ];
            extraHostNames = [ "myhost.mydomain.com" "10.10.1.4" ]
            publicKeyFile = ./pubkeys/myhost_ssh_host_dsa_key.pub;
          }
          {
            hostNames = [ "myhost2" ];
            publicKeyFile = ./pubkeys/myhost2_ssh_host_dsa_key.pub;
          }
        ]
      '';
    };
  };

  config = {

    assertions = flip mapAttrsToList cfg.knownHosts (name: data: {
      assertion = (data.publicKey == null && data.publicKeyFile != null) ||
                  (data.publicKey != null && data.publicKeyFile == null);
      message = "knownHost ${name} must contain either a publicKey or publicKeyFile";
    });

    services.openssh.authorizedKeysFiles = [ "%h/.ssh/authorized_keys" "/etc/ssh/authorized_keys.d/%u" ];

    environment.etc = authKeysFiles //
      { "ssh/ssh_known_hosts" = mkIf (builtins.length knownHosts > 0) {
          text = (flip (concatMapStringsSep "\n") knownHosts
            (h: assert h.hostNames != [];
              concatStringsSep "," h.hostNames + " "
              + (if h.publicKey != null then h.publicKey else readFile h.publicKeyFile)
            )) + "\n";
        };
        "ssh/sshd_config.d/101-authorized-keys.conf" = {
          text = "AuthorizedKeysFile ${toString config.services.openssh.authorizedKeysFiles}\n";
          # Allows us to automatically migrate from using a file to a symlink
          knownSha256Hashes = [ oldAuthorizedKeysHash ];
        };

        "ssh/ssh_config.d/200-nixos".text = ''
          GlobalKnownHostsFile ${concatStringsSep " " knownHostsFiles}
        '';
      };

    # Clean up .before-nix-darwin file left over from using knownSha256Hashes
    system.activationScripts.etc.text = ''
      auth_keys_orig=/etc/ssh/sshd_config.d/101-authorized-keys.conf.before-nix-darwin

      if [ -e "$auth_keys_orig" ] && [ "$(shasum -a 256 $auth_keys_orig | cut -d ' ' -f 1)" = "${oldAuthorizedKeysHash}" ]; then
        rm "$auth_keys_orig"
      fi
    '';
  };
}
