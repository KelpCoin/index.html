# MONEY SIGNALS AND TRIANGULATION

## Objective
Detect real revenue truth fast and avoid false optimism.

## Triangulation model
A money signal is trusted only when three points match:
1. payment processor evidence,
2. channel/source attribution,
3. local ledger entry and proof file.

## Required fields per signal
- signal_id
- offer_id
- amount
- currency
- source_channel
- timestamp_utc
- proof_path
- ledger_path

## Quality rules
- single-source claims are weak.
- two-source matches are provisional.
- three-source match is operational truth.

## Action policy
- increase allocation on repeated three-source wins.
- pause and diagnose on mismatch.
- kill if mismatch persists beyond test threshold.
