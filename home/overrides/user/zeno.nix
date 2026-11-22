# User-specific configuration for zeno on every host
{ lib, ... }:
{
  hm.langs = lib.mkDefault "nb_NO.UTF-8";
}
