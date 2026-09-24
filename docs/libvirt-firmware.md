# Libvirt QCOW2 firmware and existing VMs

The `libvirt-firmware` flake check builds snowfall's actual firmware artifacts,
checks all four installed descriptors, preserves upstream metadata, and verifies
QCOW2 headers, integrity, and byte equivalence to the RAW sources. Run it with:

```bash
nix build .#checks.x86_64-linux.libvirt-firmware --no-link -L
```

This does not prove guest boot, Secure Boot enforcement, or snapshot/revert.
The procedure below has offline image and XML validation only. Rehearse on a
backup-restored disposable VM before migrating an important guest.

## Prepare an offline migration

This procedure covers local, file-backed RAW pflash NVRAM. Network-backed NVRAM,
stateless firmware, and guests with managed-save state need separate handling.
Use the same libvirt connection that owns the VM; examples use `qemu:///system`.

1. Record the VM name, connection, autostart setting, disk paths, firmware CODE
   path, NVRAM path, template, and TPM configuration. Arrange downtime and prevent
   automatic or concurrent starts. Shut down normally and confirm `domstate`
   reports `shut off`; a paused VM is not sufficient. Do not discard managed-save
   state just to make migration proceed.

   ```bash
   virsh -c qemu:///system shutdown "$vm"
   virsh -c qemu:///system domstate "$vm"
   virsh -c qemu:///system dominfo "$vm"
   virsh -c qemu:///system dumpxml --inactive "$vm" > "$backup/domain.xml"
   virsh -c qemu:///system snapshot-list "$vm"
   ```

   Set `vm` and an existing private `backup` directory first. Wait for shutdown
   before proceeding. Keep existing snapshot metadata and backing chains intact;
   old snapshots can restore the old XML and firmware paths.

1. Back up the current NVRAM with ownership/mode preserved, the inactive XML,
   disks and their backing chains, and any swtpm state as one offline recovery
   set. Copy the recorded CODE and template files too: old store paths can be
   garbage-collected. Check that this backup can restore the guest before edits.
   Never replace populated NVRAM with a fresh template: it contains boot entries,
   enrolled keys, and other guest-specific variables.

1. Convert the **current** NVRAM to a new, unused path beside the original.
   Set `raw` to the recorded NVRAM path and `converted` to that new path. Run
   with privileges sufficient to read/write these files. Keep the VM stopped.

   ```bash
   test ! -e "$converted" && test ! -L "$converted"
   qemu-img convert -f raw -O qcow2 "$raw" "$converted"
   qemu-img info --output=json "$converted"
   qemu-img check -f qcow2 "$converted"
   qemu-img compare -f raw -F qcow2 "$raw" "$converted"
   chown --reference="$raw" "$converted"
   chmod --reference="$raw" "$converted"
   ```

   Run commands individually and stop on any failure, including the existence
   check. Confirm the reported format is QCOW2. Preserve any required ACLs and
   security labels too. Do not run image tools against a running guest's NVRAM.

## Update the persistent definition

Copy the backed-up XML to a working file. Change the existing `<nvram>` format
and file path, preserving other attributes. For example, a text-path NVRAM
entry becomes:

```xml
<nvram template='/original/template.fd' templateFormat='raw' format='qcow2'>/var/lib/libvirt/qemu/nvram/guest_VARS.qcow2</nvram>
```

For `<nvram type='file'><source file='…'/></nvram>`, update the `source` file
instead. Keep template format matched to the actual template. Keep the existing
loader and firmware feature selections for this first conversion, so a firmware
upgrade is not mixed with preserving variables.

If the intended snapshot workflow also requires QCOW2 CODE, convert a retained
copy of the guest's exact recorded CODE with the same `convert`, `check`, and
`compare` commands. Set the existing `<loader>` path to that retained conversion
and `format='qcow2'`, preserving `readonly`, `type`, and `secure`. Keep it readable
by QEMU. Select the module's `/etc/qemu/firmware-images/` CODE only after confirming
it is the intended firmware variant/version and compatible with existing VARS.

Validate the complete working XML and review its diff before defining it:

```bash
virt-xml-validate "$backup/domain-qcow2.xml" domain
diff -u "$backup/domain.xml" "$backup/domain-qcow2.xml"
virsh -c qemu:///system define --validate "$backup/domain-qcow2.xml"
virsh -c qemu:///system dumpxml --inactive "$vm"
```

Verify the readback's paths and formats before starting. Do not use
`--reset-nvram`, remove NVRAM, or regenerate it from a template.

## Runtime acceptance and rollback

On the disposable rehearsal guest, then on the migrated guest:

- Cold boot and verify boot entries, guest data, and expected UEFI variables.
- Create an internal snapshot through the intended virt-manager workflow, write
  a disposable marker in the guest, revert, and verify the marker is absent and
  the guest boots. Test the intended running/stopped snapshot modes separately.
- Repeat for the Secure Boot and swtpm combinations actually used. Verify guest
  enforcement with enrolled keys; a firmware `secure-boot` feature alone does
  not establish enforcement. Check TPM-dependent unlock behavior after revert.
- Record versions, effective XML, and snapshot/revert results. Passthrough and
  other device state can prevent snapshots independently of firmware format.

If acceptance fails, stop the VM. Restore the original XML and the coordinated
pre-migration disk/NVRAM/TPM recovery set, including retained firmware files if
original paths are gone. Define the restored XML, read it back, and cold boot.
Restoring only NVRAM after guest writes or TPM changes is not a complete rollback.
Keep the original files and backups until acceptance and recovery are proven.

## Firmware updates

The `/etc/qemu/firmware-images/` alias avoids store hashes; it neither pins a
firmware version nor guarantees unchanged upstream basenames. Keep the previous
firmware and recovery set available before an update. On a disposable guest,
verify cold boot with existing VARS, new VM autoselection, and restoration of a
pre-update snapshot/saved state against the updated firmware. Test VM creation
during activation separately if that operation is needed. An atomic `/etc`
switch does not make multiple QEMU file opens a single transaction. Do not claim
upgrade compatibility from the artifact check alone.

## References

- [Libvirt domain firmware XML](https://libvirt.org/formatdomain.html#bios-bootloader)
- [Virsh command reference](https://libvirt.org/manpages/virsh.html)
- [QEMU image conversion and comparison](https://www.qemu.org/docs/master/tools/qemu-img.html)
