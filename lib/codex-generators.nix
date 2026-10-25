{ lib, hmMaster }:
let
  upstream = import "${hmMaster}/modules/lib/generators.nix" { inherit lib; };
  # Keep the upstream merger's parsing, conflict, symlink, and cleanup behavior.
  # Fail visibly on input updates if a repair no longer matches exactly once.
  replaceOnce =
    before: after: script:
    assert lib.assertMsg (
      builtins.length (
        lib.splitString (builtins.unsafeDiscardStringContext before) (
          builtins.unsafeDiscardStringContext script
        )
      ) == 2
    ) "Codex merger compatibility repair no longer matches; review the Home Manager input.";
    lib.replaceStrings [ before ] [ after ] script;
in
{
  inherit (upstream) mkImpureConfigCleanup;

  mkImpureConfigMerger =
    args:
    let
      coreutil = lib.getExe' args.pkgs.coreutils;
      getfacl = lib.getExe' args.pkgs.acl "getfacl";
      setfacl = lib.getExe' args.pkgs.acl "setfacl";
    in
    lib.pipe (upstream.mkImpureConfigMerger args) [
      (replaceOnce ''${coreutil "cp"} --preserve=mode -- "$settings_path" "$snapshot_path"'' ''
        if ! snapshot_acl="$(${getfacl} -cpn -- "$settings_path")"; then
          errorEcho "Cannot read access controls for '$display_path'; leaving it unchanged."
          exit 1
        fi
        if ! ${coreutil "cp"} --preserve=mode,ownership -- "$settings_path" "$snapshot_path" \
          || ! ${setfacl} --set-file=<(printf '%s\n' "$snapshot_acl") -- "$snapshot_path"; then
          errorEcho "Cannot preserve access controls for '$display_path'; leaving it unchanged."
          exit 1
        fi
      '')
      (replaceOnce ''${coreutil "chmod"} --reference="$snapshot_path" -- "$candidate_path"'' ''
        # Set ownership before granting the original ACL, then restore any
        # special mode bits. Do not expose inherited named-user/group access.
        if ! ${coreutil "chown"} --reference="$snapshot_path" -- "$candidate_path" \
          || ! ${setfacl} --set-file=<(printf '%s\n' "$snapshot_acl") -- "$candidate_path" \
          || ! ${coreutil "chmod"} --reference="$snapshot_path" -- "$candidate_path"; then
          errorEcho "Cannot preserve access controls for '$display_path'; leaving it unchanged."
          exit 1
        fi
      '')
      (replaceOnce ''|| [[ "$(${coreutil "stat"} -c '%a' -- "$settings_path")" != "$(${coreutil "stat"} -c '%a' -- "$snapshot_path")" ]]; then'' ''
        || [[ "$(${coreutil "stat"} -c '%u:%g:%a' -- "$settings_path")" != "$(${coreutil "stat"} -c '%u:%g:%a' -- "$snapshot_path")" ]] \
          || ! current_acl="$(${getfacl} -cpn -- "$settings_path")" \
          || [[ "$current_acl" != "$snapshot_acl" ]]; then
      '')
    ];
}
