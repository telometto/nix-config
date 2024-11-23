# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:
{
  environment = {
    variables = {
      KUBECONFIG = "/home/${myVars.server.user}/.kube/config";
    };
  };
}
