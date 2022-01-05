{ mkOption, types, ... }:

{
  options = {
    authorizedKeys.keyFiles = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = ''
        A list of files each containing one OpenSSH public key that should be
        added to the user's authorized keys. The contents of the files are
        read at build time and added to a file that the SSH daemon reads in
        addition to the the user's authorized_keys file. You can combine the
        <literal>keyFiles</literal> and <literal>keys</literal> options.
      '';
    };
  };
}
