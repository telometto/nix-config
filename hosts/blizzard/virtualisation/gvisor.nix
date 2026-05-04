{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.gvisor ];

  systemd.services.k3s-gvisor-containerd-config = {
    description = "Write gVisor containerd runtime config for k3s";
    wantedBy = [ "k3s.service" ];
    before = [ "k3s.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /var/lib/rancher/k3s/agent/etc/containerd
      cat > /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl << 'TMPL'
      version = 2

      [plugins."io.containerd.grpc.v1.cri".containerd]
        snapshotter = "native"
        default_runtime_name = "runc"

      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
        runtime_type = "io.containerd.runc.v2"

      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
        runtime_type = "io.containerd.runsc.v1"

      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc.options]
        BinaryName = "${pkgs.gvisor}/bin/runsc"
        TypeUrl = "io.containerd.runsc.v1.options"
      TMPL
    '';
  };
}
