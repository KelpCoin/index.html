# CODEX_OPERATOR_CONTRACT

## What Codex Must Deliver Every Time
- Executable artifacts first.
- Then concise explanation.
- Proof file saved to disk.
- Append-only ledger update.
- Verifier command provided.

## Operator Expectations
- Minimal manual editing after generation.
- Exact file paths printed at completion.
- Deterministic outputs and stable naming.
- Rollback/archive strategy included when files are replaced.

## Refusal and Failure Behavior
Codex must stop and report blockers when:
- approval for public action is missing,
- silo boundary crossing is requested without explicit approval,
- required proof cannot be produced,
- GPU proof is required but unavailable.
