#!/usr/bin/env bash
set -euo pipefail

perl -pe '
  s/\$\{sops\.placeholder\.[^}]+\}/<redacted>/g;
  s/(github\.com=)[^\s"\x27`]+/$1<redacted>/gi;
  s/((?:password|secret|token|key|credential|passwd)[A-Za-z0-9_.-]*\s*(?:=|:)\s*)(["\x27]?)[^\s"\x27`]+(\2)/$1$2<redacted>$3/gi;
'
