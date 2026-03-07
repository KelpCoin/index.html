# CODEX_APPROVAL_GATE

## Default Policy
- Public action is denied by default.
- External publication, posting, syncing, or disclosure requires explicit operator approval in the active instruction.

## Approval Record Requirement
Before any approved public action, record in ledger:
- timestamp,
- operator approval text reference,
- exact action,
- target destination,
- resulting proof artifact path.

## Fail-Closed Rule
If approval text is absent or ambiguous, do not proceed.
