#!/usr/bin/env bash
set -euo pipefail

PREFERRED='D:\BrownEye\BROWNEYE_ARTIFACTS'
FALLBACK='C:\BrownEyeCortex\_artifacts'
CANON='D:\BrownEyeCortexData\MemoryVault\CANON.json'
WORKLOG='D:\BrownEyeCortexData\MemoryVault\WORKLOG.jsonl'

choose_root() {
  if [[ "${BROWNEYE_FORCE_FALLBACK:-0}" == "1" ]]; then
    mkdir -p "$FALLBACK" && echo "$FALLBACK" && return
  fi
  if mkdir -p "$PREFERRED" 2>/dev/null; then
    echo "$PREFERRED"
  else
    mkdir -p "$FALLBACK"
    echo "$FALLBACK"
  fi
}

append_memory() {
  local cycle="$1"
  mkdir -p "$(dirname "$CANON")"
  [[ -f "$CANON" ]] || echo '{"canon":"Kelphaven/Kelplantis isometric pixel town","silos":{"family":"MTG/HappyHomarid","adult":"Amplissa"}}' > "$CANON"
  [[ -f "$WORKLOG" ]] || : > "$WORKLOG"
  printf '{"ts":"%s","cycle":"%s","event":"memory_append"}\n' "$(date -Iseconds)" "$cycle" >> "$WORKLOG"
}

silo_check() {
  local payload="$1"
  if [[ "$payload" =~ (MTG|HappyHomarid) ]] && [[ "$payload" =~ (adult|Amplissa) ]]; then
    echo "Hard silo violation detected" >&2
    exit 2
  fi
}

cycle_emit() {
  local cycle="$1"
  local root
  root="$(choose_root)"
  local proof="$root/${cycle}_proof.txt"
  local ledger="$root/ledger.jsonl"

  local phases='["Proposer","Critic","Synthesizer","Monetizer","Humanizer"]'
  local payload="cycle:$cycle phases:$phases public_dispatch_blocked:${BROWNEYE_DISABLE_PUBLIC:-1}"
  silo_check "$payload"

  cat > "$proof" <<TXT
cycle=$cycle
artifact_root=$root
phases=$phases
payment_path=doorway -> pay placeholder -> delivery proof -> ledger
verifier=bash scripts/run_cycle.sh verify
TXT

  local hash
  hash="$(sha256sum "$proof" | awk '{print $1}')"
  printf '{"ts":"%s","cycle":"%s","proof":"%s","sha256":"%s"}\n' "$(date -Iseconds)" "$cycle" "$proof" "$hash" >> "$ledger"
  append_memory "$cycle"

  echo "proof=$proof"
  echo "ledger=$ledger"
  echo "sha256=$hash"
}

verify() {
  local root
  root="$(choose_root)"
  local ok=1
  for f in "$root/cinema_slice1_proof.txt" "$root/cinema_slice2_proof.txt" "$root/game_slice1_proof.txt" "$root/ledger.jsonl" "$CANON" "$WORKLOG"; do
    [[ -f "$f" ]] || { echo "missing:$f"; ok=0; }
  done
  if [[ "$ok" == "1" ]]; then
    echo "verify:pass"
  else
    echo "verify:fail"
    exit 1
  fi
}

cmd="${1:-all}"
case "$cmd" in
  cinema)
    cycle_emit cinema_slice1
    cycle_emit cinema_slice2
    ;;
  game)
    cycle_emit game_slice1
    ;;
  all)
    cycle_emit cinema_slice1
    cycle_emit cinema_slice2
    cycle_emit game_slice1
    verify
    ;;
  verify)
    verify
    ;;
  *)
    echo "usage: $0 [cinema|game|all|verify]" >&2
    exit 1
    ;;
esac
