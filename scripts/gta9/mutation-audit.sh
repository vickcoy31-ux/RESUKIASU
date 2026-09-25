#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <source-tree> <baseline-manifest> <report>"
  exit 2
}

SRC=${1:-}
BASELINE=${2:-}
REPORT=${3:-}

[ -d "$SRC" ] && [ -f "$BASELINE" ] && [ -n "$REPORT" ] || usage
mkdir -p "$(dirname "$REPORT")"

fail=0
{
  echo "GTA9 SOURCE MUTATION AUDIT"
  echo "=========================="
  echo "SOURCE=$SRC"
  echo "BASELINE=$BASELINE"
  echo

  while read -r expected path; do
    [ -n "${path:-}" ] || continue
    file="$SRC/$path"
    if [ ! -f "$file" ]; then
      echo "FAIL missing: $path"
      fail=1
      continue
    fi
    actual=$(sha256sum "$file" | awk '{print $1}')
    if [ "$actual" = "$expected" ]; then
      echo "PASS unchanged: $path"
    else
      echo "FAIL changed: $path"
      echo "  expected=$expected"
      echo "  actual=$actual"
      fail=1
    fi
  done < "$BASELINE"

  echo
  echo
  echo "Tracked protected-path status:"
  status=$(git -C "$SRC" status --porcelain -- \
    arch/arm64/mm \
    arch/arm64/include/asm/tlb.h \
    arch/arm64/include/asm/tlbflush.h \
    arch/arm64/include/asm/mmu_context.h \
    arch/arm64/include/asm/pgtable.h \
    arch/arm64/include/asm/pgtable-prot.h)
  if [ -n "$status" ]; then
    printf '%s\\n' "$status"
    echo "FAIL unexpected tracked/untracked change in protected MMU paths"
    fail=1
  else
    echo "PASS no protected-path git mutations"
  fi

  echo
  echo "MMU_SOURCE_MUTATION=$([ "$fail" -eq 0 ] && echo PASS || echo FAIL)"
} | tee "$REPORT"

exit "$fail"
