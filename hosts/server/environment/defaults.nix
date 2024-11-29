# Host-specific system configuration defaults
{ config, lib, pkgs, myVars, ... }:
{
  environment = {
    variables = {
      KUBECONFIG = "/home/${myVars.users.serverAdmin.user}/.kube/config";
    };
  };
}
