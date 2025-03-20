# Host-specific system configuration defaults
{ config, lib, pkgs, VARS, ... }:
let
  jdkWithFX = pkgs.jdk23.override {
    enableJavaFX = true;
    # openjfx_jdk = pkgs.openjfx.override { withWebKit = true; }; # Uncomment this line to enable WebKit
  };
in
{
  programs = {
    java = {
      enable = true;
      package = jdkWithFX;
    };
  };
}
