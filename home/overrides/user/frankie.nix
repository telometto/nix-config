# User-specific configuration for frankie on every host
{ lib, ... }:
let
  locale = "it_IT.UTF-8";
in
{
  hm.langs = lib.mkDefault locale;

  home.language = {
    base = lib.mkOverride 900 locale;
    messages = lib.mkOverride 900 locale;
  };
}
