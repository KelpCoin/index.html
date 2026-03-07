# Guardrails and Silo Rules

## Non-negotiable silo split
- Silo A: MTG, HappyHomarid, CollectorsCoast
- Silo B: Amplissa, adult

No shared credentials, assets, prompts, campaign plans, or customer data across silos.

## Public action guardrail
No public posting, publishing, outreach, ad launch, or account change without explicit approval.

## Approval record minimum
- Requestor
- Proposed action
- Scope
- Timestamp
- Approver identity
- Approval proof file path

## Data handling
- Store proofs, logs, and ledgers locally.
- Prefer D:\ paths.
- Use C:\ fallback only when D:\ is unavailable.
- Use archive/replace, not delete.

## Execution guardrails
- Idempotent scripts only.
- Batch-safe defaults.
- No hidden side effects.
- Every meaningful run writes proof and JSONL ledger entry.
