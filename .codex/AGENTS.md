# Codex Local Control Plane Instructions (.codex scope)

Scope: .codex directory tree only.

## Purpose
This folder defines the persistent behavior profile for Codex runs in BrownEye Cortex workspaces.

## Behavioral Contract
- Use implementation-first execution: create or modify files before long-form explanation.
- Keep changes deterministic: fixed naming, stable folder layout, repeatable scripts.
- Keep docs and scripts ASCII-only.
- Never delete governed files directly. Archive and replace.

## Required Pre-Edit Inspection
Before changing governed files:
1. Enumerate expected spine files.
2. Validate existing hashes/state where possible.
3. Record a pre-change ledger line.

## Required Post-Edit Actions
After changing governed files:
1. Run verifier.
2. Write proof artifact with timestamp, host, and verification result.
3. Append ledger entry (never rewrite previous lines).
4. Emit exact paths for artifacts, proof, and ledger.

## Safety Constraints
- Deny-by-default for public posting, remote publication, or external sharing.
- Respect silo boundaries and fail closed on ambiguity.
- Preserve active working modules when layering updates.
