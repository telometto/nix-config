# One shared migration base per repository

The user approved correcting the branch layout: absorb host foundation PRs
#7320 and #7324 into #5894, keep #5894 unmerged into main, and make each service
PR target one common base. This authorization supersedes the earlier prohibition
on these foundation integrations and the necessary common-base ancestry updates.
It does not authorize service merges into the umbrella, main merges, deployment,
activation, Flux changes, production access or runtime implementation.

## Selected approach

Use forward-only commits and normal pushes, preserving every service PR and its
existing history. The host umbrella's actual head remains dev-kubevirt; canonical
dev/kubevirt stays synchronized. Every host service PR, including SearxNG, targets
dev-kubevirt directly. The former base/groundwork refs become historical refs.

The homelab-apps umbrella remains #14, head dev/kubevirt-groundwork, targeting
main. Remove SearxNG's implementation from that common tree while retaining its
generic namespace-scoping and shared systemd-test helpers. Reintroduce the same
SearxNG source only on its existing service branch #13. All seventeen application
service PRs target #14's head. This avoids placing a service underneath the shared
base and preserves independent choices without a published-history rewrite.

A metadata-only retarget before consolidation would duplicate shared code in
service diffs. Rebasing all published branches would rewrite their histories.
The selected method incorporates the approved shared source and aligns service
ancestry with ordinary forward-only commits; no additional user decision remains.

## Boundaries and evidence

Preserve every application payload, serial, retained path, pin, stopped state,
policy and disabled host registration. Empty reservation slots stay on common;
actual service definitions stay only on service branches. Keep all service PRs
and both umbrellas draft/no-auto-merge. Absorbed host foundation PRs may be marked
merged by GitHub; do not delete their branches or merge either umbrella to main.

Record before/after refs. Verify the old service heads are ancestors of the new
heads, every common head is an ancestor/merge-base, no service depends on another,
and each effective PR diff is service-owned. Test the common-only and combined
source, including SearxNG, with existing public contracts and compare old/new
runtime payloads byte-for-byte. Build the final host base and check GitHub CI.
Update shared guidance and temporary agent handoffs with the new exact heads.
