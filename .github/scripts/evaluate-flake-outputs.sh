#!/usr/bin/env bash
set -euo pipefail

flake_ref="${1:-path:.}"
flake_system="x86_64-linux"
evaluation_timeout="${FLAKE_EVAL_TIMEOUT:-15m}"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
redactor="$script_dir/redact-secrets.sh"
evaluation_output=$(mktemp)
evaluation_names=$(mktemp)
trap 'rm -f -- "$evaluation_output" "$evaluation_names"' EXIT

append_summary() {
  if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
    printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"
  fi
}

start_group() {
  if [[ ${GITHUB_ACTIONS:-} == "true" ]]; then
    printf '::group::%s\n' "$1"
  fi
}

end_group() {
  if [[ ${GITHUB_ACTIONS:-} == "true" ]]; then
    printf '::endgroup::\n'
  fi
}

report_failure() {
  local label=$1
  local exit_status=$2

  printf '❌ %s failed (exit %s)\n' "$label" "$exit_status" >&2
  bash "$redactor" < "$evaluation_output" | tail -n 200 >&2

  if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
    {
      printf -- '- ❌ %s failed (exit %s)\n\n' "$label" "$exit_status"
      printf '<details><summary>Redacted evaluation output</summary>\n\n```text\n'
      bash "$redactor" < "$evaluation_output" | tail -n 200
      printf '```\n</details>\n'
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

list_attr_names() {
  local label=$1
  local installable=$2
  local result_variable=$3
  local exit_status

  printf 'Discovering %s...\n' "$label"
  : > "$evaluation_output"
  : > "$evaluation_names"

  if timeout "$evaluation_timeout" nix eval --raw "$installable" \
    --apply 'attrs: builtins.concatStringsSep "\n" (builtins.attrNames attrs)' \
    > "$evaluation_names" 2> "$evaluation_output"; then
    if [[ -s $evaluation_output ]]; then
      bash "$redactor" < "$evaluation_output"
    fi
    printf -v "$result_variable" '%s' "$(< "$evaluation_names")"
  else
    exit_status=$?
    report_failure "Discover $label" "$exit_status"
    return "$exit_status"
  fi
}

evaluate_attr() {
  local label=$1
  local installable=$2
  local exit_status

  start_group "Evaluate $label"
  printf 'Evaluating %s...\n' "$label"
  : > "$evaluation_output"
  : > "$evaluation_names"

  if timeout "$evaluation_timeout" nix eval --raw "$installable" \
    > "$evaluation_names" 2> "$evaluation_output"; then
    if [[ -s $evaluation_output ]]; then
      bash "$redactor" < "$evaluation_output"
    fi
    printf '✅ %s evaluated successfully\n' "$label"
    append_summary "- ✅ $label"
    end_group
  else
    exit_status=$?
    report_failure "$label" "$exit_status"
    end_group
    return "$exit_status"
  fi
}

configuration_names=""
check_names=""
dev_shell_names=""

append_summary "## 🔍 Flake Output Evaluation"

list_attr_names \
  "NixOS configurations" \
  "$flake_ref#nixosConfigurations" \
  configuration_names

while IFS= read -r configuration_name; do
  [[ -n $configuration_name ]] || continue
  evaluate_attr \
    "nixosConfigurations.$configuration_name" \
    "$flake_ref#nixosConfigurations.$configuration_name.config.system.build.toplevel.drvPath"
done <<< "$configuration_names"

evaluate_attr \
  "formatter.$flake_system" \
  "$flake_ref#formatter.$flake_system.drvPath"

list_attr_names \
  "checks for $flake_system" \
  "$flake_ref#checks.$flake_system" \
  check_names

while IFS= read -r check_name; do
  [[ -n $check_name ]] || continue
  evaluate_attr \
    "checks.$flake_system.$check_name" \
    "$flake_ref#checks.$flake_system.$check_name.drvPath"
done <<< "$check_names"

list_attr_names \
  "development shells for $flake_system" \
  "$flake_ref#devShells.$flake_system" \
  dev_shell_names

while IFS= read -r dev_shell_name; do
  [[ -n $dev_shell_name ]] || continue
  evaluate_attr \
    "devShells.$flake_system.$dev_shell_name" \
    "$flake_ref#devShells.$flake_system.$dev_shell_name.drvPath"
done <<< "$dev_shell_names"

append_summary ""
append_summary "Each output was evaluated in a separate Nix process to bound peak memory."
printf 'All flake outputs evaluated successfully in isolated Nix processes.\n'
