_:
{
  # gVisor deferred — the containerd config.toml.tmpl written by the previous
  # implementation overwrote k3s's own containerd config entirely (omitting
  # Go-template variables like {{ .NodeConfig.AgentConfig.CNIBinDir }}), which
  # caused FailedCreatePodSandBox for every pod including the Cilium DaemonSet.
  #
  # Fix (deferred to a future plan): the template must start with
  #   {{ template "base" . }}
  # so k3s expands its own defaults before the gVisor runtime block is appended.
  #
  # The old RuntimeClass "gvisor" manifest was removed from homelab-apps. Do
  # not reintroduce it until the host-side runtime is deliberately configured.
}
