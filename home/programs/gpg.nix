{ lib, config, ... }:
let
  cfg = config.hm.programs.gpg;
in
{
  options.hm.programs.gpg = {
    enable = lib.mkEnableOption "GPG configuration";

    homedir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.gnupg";
      description = "GPG home directory";
    };

    mutableTrust = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow trustdb modifications";
    };

    mutableKeys = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow key modifications";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional GPG settings";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.gpg = {
      enable = lib.mkDefault true;

      inherit (cfg) homedir mutableTrust mutableKeys;

      settings = lib.mkMerge [
        {
          # General settings
          no-greeting = true;
          no-emit-version = true;
          no-comments = false;

          # Export options
          export-options = "export-minimal";
          keyid-format = "0xlong";
          with-fingerprint = true;
          with-keygrip = true;

          list-options = "show-uid-validity";
          verify-options = "show-uid-validity show-keyserver-urls";

          personal-cipher-preferences = "AES256";
          personal-digest-preferences = "SHA512";
          default-preference-list = "SHA512 SHA384 SHA256 RIPEMD160 AES256 TWOFISH BLOWFISH ZLIB BZIP2 ZIP Uncompressed";
          cipher-algo = "AES256";
          digest-algo = "SHA512";
          cert-digest-algo = "SHA512";
          compress-algo = "ZLIB";

          disable-cipher-algo = "3DES";
          weak-digest = "SHA1";

          s2k-cipher-algo = "AES256";
          s2k-digest-algo = "SHA512";
          s2k-mode = "3";
          s2k-count = "65011712";
        }
        cfg.extraSettings
      ];
    };
  };
}
