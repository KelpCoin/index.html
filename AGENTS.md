# BrownEye Cortex Codex Operating Spine (Repository Root)

Scope: Entire repository unless a deeper AGENTS.md overrides specific rules.

## Mission Priority
1. Build executable deliverables first.
2. Write proof artifacts and append-only ledger entries.
3. Explain only after artifacts are on disk.

## Required Operating Mode
- Treat this workspace as a hardened local engineering environment.
- Prefer deterministic workflows, reproducible outputs, and exact file paths.
- Inspect the workspace before editing. Identify existing modules and avoid breaking known-working systems.
- Preserve current behavior by default. If replacement is required, archive and replace. Do not hard-delete.
- Keep operator load low: produce no-close launchers, verifier commands, and minimal manual steps.

## Platform and Runtime Laws
- Windows 11 assumptions.
- PowerShell 5.1 only unless explicitly instructed otherwise.
- ASCII only for scripts and canonical docs.
- Prefer D:\ paths for generated runtime artifacts; use C:\ only as fallback.

## Security, Approval, and Silo Laws
- Public actions are deny-by-default until explicit approval is present in the active prompt.
- Enforce hard silo separation. Do not merge or cross-read silo data unless explicitly approved.
- Fail closed: if required approvals, dependencies, or proof conditions are missing, stop and report exact blockers.
- Never bluff success.

## Output and Proof Laws
- Every substantial task must output:
  - concrete artifacts written to disk,
  - a proof file,
  - an append-only ledger update,
  - a verifier command.
- Include health checks in generated workflows.
- Avoid placeholders such as "TODO", "fill in", "example only" in final deliverables.
- End responses with exact absolute or repo-relative file paths for generated outputs.

## GPU Rule
- If GPU proof is required by task constraints, do not silently fall back to CPU.
- If GPU proof cannot be produced, fail closed and state that proof requirement is unmet.

## Migration Rule for Existing BrownEye Systems
- Layer changes non-destructively over active BrownEye folders.
- Preserve working modules, configs, and state. Add side-by-side overlays and archive replaced files.

## Operator-Facing Communication Standard
- Keep docs actionable for tired operators:
  - short command blocks,
  - deterministic paths,
  - explicit pass/fail checks,
  - rollback notes.
