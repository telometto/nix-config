# Infrastructure Configuration

This context describes how hosts and their workloads are made available to
clients while keeping application publication distinct from network access.

## Language

**Public HTTP publication**:
An explicitly enabled, hostname-based path that makes one enabled workload target
available to public web clients through the managed HTTP edge. Each publication
has exactly one hostname under the canonical public domain and one target.
_Avoid_: Public exposure, ingress

**Canonical public domain**:
The domain suffix under which standard public HTTP publications are named.
_Avoid_: Base domain, primary domain

**Publication policy**:
The security, abuse-protection, and workload-compatibility requirements attached
to a public HTTP publication. Every standard publication policy includes abuse
protection and a strict security baseline, and describes intent rather than
edge-specific configuration.
_Avoid_: Middleware list, route configuration

**Compatibility policy**:
A named, route-scoped variation of the strict publication policy required by a
workload that cannot operate under the baseline. It changes only the behavior
that is incompatible.
_Avoid_: Header override, custom middleware chain

**Network exposure**:
Transport-layer reachability that makes a workload port accessible beyond its
private VM network. It does not imply public HTTP availability.
_Avoid_: Publication
