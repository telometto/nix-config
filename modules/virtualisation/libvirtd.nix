{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.sys.virtualisation.libvirtd;
  qemu = config.virtualisation.libvirtd.qemu.package;
  firmwareDescriptors = [
    "50-edk2-i386-secure.json"
    "50-edk2-x86_64-secure.json"
    "60-edk2-i386.json"
    "60-edk2-x86_64.json"
  ];
  # Internal UEFI snapshots require QCOW2 NVRAM. Keep the upstream firmware
  # features and machine matching, but prefer QCOW2 for newly created VMs.
  snapshotFirmware =
    pkgs.runCommand "libvirt-qcow2-firmware"
      {
        nativeBuildInputs = [
          pkgs.jq
          qemu
        ];
      }
      ''
        mkdir -p "$out/firmware" "$out/images"
        for descriptor in ${lib.escapeShellArgs firmwareDescriptors}; do
          source="${qemu}/share/qemu/firmware/$descriptor"
          code=$(jq -er '.mapping.executable.filename' "$source")
          vars=$(jq -er '.mapping["nvram-template"].filename' "$source")
          code_out="$out/images/$(basename "$code").qcow2"
          vars_out="$out/images/$(basename "$vars").qcow2"
          for pair in code vars; do
            if [ "$pair" = code ]; then
              input="$code"; output="$code_out"
            else
              input="$vars"; output="$vars_out"
            fi
            if [ ! -e "$output" ]; then
              qemu-img convert -f raw -O qcow2 "$input" "$output"
            fi
          done
          jq --arg code "/etc/qemu/firmware-images/$(basename "$code_out")" \
             --arg vars "/etc/qemu/firmware-images/$(basename "$vars_out")" '
            .mapping.executable = {filename: $code, format: "qcow2"}
            | .mapping["nvram-template"] = {filename: $vars, format: "qcow2"}
          ' "$source" > "$out/firmware/$descriptor"
        done
      '';
in
{
  options.sys.virtualisation.libvirtd = {
    enable = lib.mkEnableOption "libvirtd for running VMs";

    networkBridge = lib.mkOption {
      type = lib.types.str;
      default = "virbr0";
      description = "Network bridge for VMs";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true;
        vhostUserPackages = [ pkgs.virtiofsd ];
      };
    };

    programs.virt-manager.enable = true;

    # Earlier filenames win firmware autoselection. Keep RAW descriptors
    # available for existing VMs whose firmware paths are already recorded.
    environment.etc = {
      # Avoid store-hash paths; upstream basenames and firmware versions can change.
      "qemu/firmware-images".source = "${snapshotFirmware}/images";
    }
    // lib.genAttrs (map (name: "qemu/firmware/10-${name}") firmwareDescriptors) (path: {
      source = "${snapshotFirmware}/firmware/${lib.removePrefix "qemu/firmware/10-" path}";
    });

    # swtpm_localca needs a writable state directory owned by tss:tss
    systemd.tmpfiles.rules = [
      "d /var/lib/swtpm-localca 0750 tss tss -"
    ];

    environment.systemPackages = with pkgs; [
      libvirt
      virt-viewer
      dnsmasq
      virtio-win
    ];

    networking.firewall.trustedInterfaces = [ cfg.networkBridge ];
  };
}
