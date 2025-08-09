# Utility functions for the configuration
{ lib, VARS }:

let
  # Allow roles to be defined as a single hostname or list in VARS
  toList = x: if builtins.isList x then x else [ x ];
  desktopHosts = toList VARS.systems.desktop.hostName;
  laptopHosts = toList VARS.systems.laptop.hostName;
  serverHosts = toList VARS.systems.server.hostName;
  rolesByHost =
    lib.listToAttrs (
      (map (h: { name = h; value = "desktop"; }) desktopHosts)
      ++ (map (h: { name = h; value = "laptop"; }) laptopHosts)
      ++ (map (h: { name = h; value = "server"; }) serverHosts)
    );
in rec {
  deviceTypes = {
    desktop = desktopHosts;
    laptop = laptopHosts;
    server = serverHosts;
  };

  roleOf = hostName: rolesByHost.${hostName} or null;

  isDesktop = hostName: roleOf hostName == "desktop";
  isLaptop = hostName: roleOf hostName == "laptop";
  isServer = hostName: roleOf hostName == "server";
  isWorkstation = hostName: let r = roleOf hostName; in r == "desktop" || r == "laptop";

  mkModule = { condition ? true, config }: lib.mkIf condition config;

  mkDesktopConfig = hostName: config: mkModule { condition = isDesktop hostName; inherit config; };
  mkLaptopConfig = hostName: config: mkModule { condition = isLaptop hostName; inherit config; };
  mkServerConfig = hostName: config: mkModule { condition = isServer hostName; inherit config; };
  mkWorkstationConfig = hostName: config: mkModule { condition = isWorkstation hostName; inherit config; };

  # Expose rolesByHost for debugging / assertions
  roles = rolesByHost;
}
