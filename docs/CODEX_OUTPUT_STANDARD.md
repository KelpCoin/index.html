# CODEX_OUTPUT_STANDARD

## Delivery Order
1. Build artifacts to disk.
2. Run verification.
3. Write proof artifact.
4. Append ledger entry.
5. Provide concise summary with exact paths and commands.

## Minimum Output Set Per Task
- Primary artifact(s)
- Verifier script or command
- Proof file under proof/
- Ledger append under ledger/
- Rollback/archive note when replacements occurred

## Response Tail Requirements
At completion, always print:
- what changed
- where Codex instruction files are
- how future Codex runs inherit them
- proof path
- ledger path
- verifier command
