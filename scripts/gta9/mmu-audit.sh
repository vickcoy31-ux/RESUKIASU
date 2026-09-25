#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <source-tree> <final-config> <report> [baseline-manifest]"
  exit 2
}

SRC=${1:-}
CFG=${2:-}
REPORT=${3:-}
BASELINE=${4:-}

[ -n "$SRC" ] && [ -d "$SRC" ] || usage
[ -n "$CFG" ] && [ -f "$CFG" ] || { echo "MMU AUDIT: config missing: $CFG"; exit 1; }
[ -n "$REPORT" ] || usage

mkdir -p "$(dirname "$REPORT")"
fail=0

expect_cfg() {
  local key=$1 expected=$2 actual
  actual=$(sed -nE "s/^[[:space:]]*${key}=(.*)$/\1/p" "$CFG" | tail -n1)
  if [ "$actual" = "$expected" ]; then
    printf 'PASS %-36s expected=%s actual=%s\n' "$key" "$expected" "$actual"
  else
    printf 'FAIL %-36s expected=%s actual=%s\n' "$key" "$expected" "${actual:-<unset>}"
    fail=1
  fi
}

{
  echo "GTA9 MMU / ARM64 TRANSLATION AUDIT"
  echo "================================="
  echo "SOURCE=$SRC"
  echo "CONFIG=$CFG"
  echo

  expect_cfg CONFIG_MMU y
  expect_cfg CONFIG_ARM64_PAGE_SHIFT 12
  expect_cfg CONFIG_ARM64_4K_PAGES y
  expect_cfg CONFIG_ARM64_VA_BITS_39 y
  expect_cfg CONFIG_ARM64_VA_BITS 39
  expect_cfg CONFIG_ARM64_PA_BITS_48 y
  expect_cfg CONFIG_ARM64_PA_BITS 48
  expect_cfg CONFIG_ARM64_SW_TTBR0_PAN y
  expect_cfg CONFIG_ARM64_PAN y
  expect_cfg CONFIG_ARM64_HW_AFDBM y
  expect_cfg CONFIG_ARM64_TLB_RANGE y
  expect_cfg CONFIG_ARM64_E0PD y
  expect_cfg CONFIG_RODATA_FULL_DEFAULT_ENABLED y
  expect_cfg CONFIG_RELOCATABLE y
  expect_cfg CONFIG_RANDOMIZE_BASE y

  echo
  echo "Protected MMU source hashes:"
  if [ -n "$BASELINE" ] && [ -f "$BASELINE" ]; then
    if ( cd "$SRC" && sha256sum -c "$BASELINE" ); then
      echo "MMU_SOURCE_HASH=PASS"
    else
      echo "MMU_SOURCE_HASH=FAIL"
      fail=1
    fi
  else
    echo "MMU_SOURCE_HASH=NOT_RUN"
  fi

  echo
  echo "MMU derived constants:"
  grep -nE '^(#define[[:space:]]+(VA_BITS|VA_BITS_MIN)|[[:space:]]*(u64[[:space:]]+)?idmap_t0sz)'     "$SRC/arch/arm64/mm/mmu.c" "$SRC/arch/arm64/mm/proc.S" 2>/dev/null || true

  echo
  echo "MMU_STATUS=$([ "$fail" -eq 0 ] && echo PASS || echo FAIL)"
} | tee "$REPORT"

exit "$fail"
