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
  # The RuntimeClass "gvisor" Kustomization in homelab-apps/kubevirt/ is harmless
  # to leave deployed — it only creates a CRD instance referencing handler "runsc",
  # which does nothing until the runtime is actually registered in containerd.
}
