{ config, lib, pkgs, ... }:

let
  cfg = config.programs.ssh;

  knownHosts = builtins.attrValues cfg.knownHosts;

  knownHostsFiles = [ "/etc/ssh/ssh_known_hosts" "/etc/ssh/ssh_known_hosts2" ]
    ++ map pkgs.copyPathToStore cfg.knownHostsFiles;

  host =
    { name, config, ... }:
    {
      options = {
        certAuthority = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            This public key is an SSH certificate authority, rather than an
            individual host's key.
          '';
        };
        hostNames = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ name ] ++ config.extraHostNames;
          description = ''
            The set of system-wide known SSH hosts. To make simple setups more
            convenient the name of an attribute in this set is used as a host name
            for the entry. This behaviour can be disabled by setting
            `hostNames` explicitly. You can use
            `extraHostNames` to add additional host names without
            disabling this default.
          '';
        };
        extraHostNames = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = ''
            A list of additional host names and/or IP numbers used for
            accessing the host's ssh service. This list is ignored if
            `hostNames` is set explicitly.
          '';
        };
        publicKey = lib.mkOption {
          default = null;
          type = lib.types.nullOr lib.types.str;
          example = "ecdsa-sha2-nistp521 AAAAE2VjZHN...UEPg==";
          description = ''
            The public key data for the host. You can fetch a public key
            from a running SSH server with the {command}`ssh-keyscan`
            command. The public key should not include any host names, only
            the key type and the key itself.
          '';
        };
        publicKeyFile = lib.mkOption {
          default = null;
          type = lib.types.nullOr lib.types.path;
          description = ''
            The path to the public key file for the host. The public
            key file is read at build time and saved in the Nix store.
            You can fetch a public key file from a running SSH server
            with the {command}`ssh-keyscan` command. The content
            of the file should follow the same format as described for
            the `publicKey` option.
          '';
        };
      };
    };
  # Taken from: https://github.com/NixOS/nixpkgs/blob/f4aa6afa5f934ece2d1eb3157e392d056be01617/nixos/modules/services/networking/ssh/sshd.nix#L46-L93
  userOptions = {

    options.openssh.authorizedKeys = {
      keys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          A list of verbatim OpenSSH public keys that should be added to the
          user's authorized keys. The keys are added to a file that the SSH
          daemon reads in addition to the the user's authorized_keys file.
          You can combine the `keys` and
          `keyFiles` options.
          Warning: If you are using `NixOps` then don't use this
          option since it will replace the key required for deployment via ssh.
        '';
      };

      keyFiles = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [];
        description = ''
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
    mkAuthKeyFile = u: lib.nameValuePair "ssh/nix_authorized_keys.d/${u.name}" {
      text = ''
        ${builtins.concatStringsSep "\n" u.openssh.authorizedKeys.keys}
        ${lib.concatMapStrings (f: builtins.readFile f + "\n") u.openssh.authorizedKeys.keyFiles}
      '';
    };
    usersWithKeys = builtins.attrValues (lib.flip lib.filterAttrs config.users.users (n: u:
      lib.length u.openssh.authorizedKeys.keys != 0 || lib.length u.openssh.authorizedKeys.keyFiles != 0
    ));
  in lib.listToAttrs (map mkAuthKeyFile usersWithKeys);

  oldAuthorizedKeysHash = "5a5dc1e20e8abc162ad1cc0259bfd1dbb77981013d87625f97d9bd215175fc0a";
in

{
  imports = [
    (lib.mkRemovedOptionModule [ "services" "openssh" "authorizedKeysFiles" ] "No `nix-darwin` equivalent to this NixOS option.")
  ];

  options = {

    users.users = lib.mkOption {
      type = with lib.types; attrsOf (submodule userOptions);
    };

    programs.ssh.extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Extra configuration text loaded in {file}`ssh_config`.
        See {manpage}`ssh_config(5)` for help.
       '';
    };

    programs.ssh.knownHostsFiles = lib.mkOption {
      default = [];
      type = lib.types.listOf lib.types.path;
      description = ''
        Files containing SSH host keys to set as global known hosts.
        <literal>/etc/ssh/ssh_known_hosts</literal> (which is
        generated by <option>programs.ssh.knownHosts</option>) and
        <literal>/etc/ssh/ssh_known_hosts2</literal> are always
        included.
      '';
      example = lib.literalExpression ''
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

    programs.ssh.knownHosts = lib.mkOption {
      default = {};
      type = lib.types.attrsOf (lib.types.submodule host);
      description = ''
        The set of system-wide known SSH hosts. To make simple setups more
        convenient the name of an attribute in this set is used as a host name
        for the entry. This behaviour can be disabled by setting
        `hostNames` explicitly. You can use
        `extraHostNames` to add additional host names without
        disabling this default.
      '';
      example = lib.literalExpression ''
        {
          myhost = {
            extraHostNames = [ "myhost.mydomain.com" "10.10.1.4" ];
            publicKeyFile = ./pubkeys/myhost_ssh_host_dsa_key.pub;
          };
          "myhost2.net".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILIRuJ8p1Fi+m6WkHV0KWnRfpM1WxoW8XAS+XvsSKsTK";
          "myhost2.net/dsa" = {
            hostNames = [ "myhost2.net" ];
            publicKeyFile = ./pubkeys/myhost2_ssh_host_dsa_key.pub;
          };
        }
      '';
    };
  };

  config = {

    assertions = lib.flip lib.mapAttrsToList cfg.knownHosts (name: data: {
      assertion = (data.publicKey == null && data.publicKeyFile != null) ||
                  (data.publicKey != null && data.publicKeyFile == null);
      message = "knownHost ${name} must contain either a publicKey or publicKeyFile";
    });

    environment.etc = authKeysFiles //
      { "ssh/ssh_known_hosts" = lib.mkIf (builtins.length knownHosts > 0) {
          text = (lib.flip (lib.concatMapStringsSep "\n") knownHosts
            (h: assert h.hostNames != [];
              lib.optionalString h.certAuthority "@cert-authority " + builtins.concatStringsSep "," h.hostNames + " "
              + (if h.publicKey != null then h.publicKey else builtins.readFile h.publicKeyFile)
            )) + "\n";
        };
        "ssh/ssh_config.d/100-nix-darwin.conf".text = config.programs.ssh.extraConfig;
        "ssh/sshd_config.d/101-authorized-keys.conf" = {
          text = ''
            # sshd doesn't like reading from symbolic links, so we cat
            # the file ourselves.
            AuthorizedKeysCommand /bin/cat /etc/ssh/nix_authorized_keys.d/%u
            # Just a simple cat, fine to use _sshd.
            AuthorizedKeysCommandUser _sshd
          '';
          # Allows us to automatically migrate from using a file to a symlink
          knownSha256Hashes = [ oldAuthorizedKeysHash ];
        };

        "ssh/ssh_config.d/200-nixos".text = ''
          GlobalKnownHostsFile ${lib.concatStringsSep " " knownHostsFiles}
        '';
      };

    system.activationScripts.etc.text = ''
      # Clean up .before-nix-darwin file left over from using knownSha256Hashes
      auth_keys_orig=/etc/ssh/sshd_config.d/101-authorized-keys.conf.before-nix-darwin

      if [ -e "$auth_keys_orig" ] && [ "$(shasum -a 256 $auth_keys_orig | cut -d ' ' -f 1)" = "${oldAuthorizedKeysHash}" ]; then
        rm "$auth_keys_orig"
      fi
    '';
  };
}
