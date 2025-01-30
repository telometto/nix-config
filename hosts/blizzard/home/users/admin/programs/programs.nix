{ config, lib, pkgs, VARS, ... }:

{
  programs = {
    keychain = {
      keys = [ "borg-blizzard" "sops-hm-blizzard" "zeno-blizzard" ];
    };

    zsh = {
      shellAliases = {
        # Kubernetes
        k = "kubectl";
        kap = "kubectl apply -f";
        kdl = "kubectl delete";
        kgt = "kubectl get";
        kex = "kubectl exec -it";
        klo = "kubectl logs";
        kev = "kubectl events";
        kds = "kubectl describe";
      };
    };
  };
}
