# Revenue Cell Stencil

## Purpose
Use this stencil to create low-operator-load, approval-gated revenue cells with mandatory proof and append-only ledger behavior.

## Required fields
- offer_name
- silo
- offer_summary
- audience
- price_logic
- delivery_logic
- proof_artifact_format
- ledger_format
- verifier_command
- risk_flags
- approval_status
- kill_condition
- clone_condition
- operator_load_estimate
- dependencies
- success_criteria

## Enforcement rules
1. approval_status starts as quarantined unless explicit approval event is logged.
2. No public action is allowed while approval_status is quarantined.
3. Proof-on-disk is required before fulfillment_complete events.
4. Ledger writes are append-only JSONL events.
5. No scale actions are allowed before paid_signal is true.
6. Silos must not be mixed in one cell package.

## Lifecycle
1. Birth: New_RevenueCell.ps1 stamps package and baseline proof.
2. Verify: Verify_RevenueFactory.ps1 validates schema, proof, and ledger compliance.
3. Measure: Append paid_signal and fulfillment events to ledger.
4. Kill: Trigger kill if kill_condition is met.
5. Clone: Trigger clone if clone_condition is met.
