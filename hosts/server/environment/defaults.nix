# Host-specific system configuration defaults
{ config, lib, pkgs, VARS, ... }:
{
  environment = {
    variables = {
      KUBECONFIG = "/home/${VARS.users.admin.user}/.kube/config";
    };
  };
}
