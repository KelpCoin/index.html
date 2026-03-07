# GUARDRAILS AND SILO RULES

## Hard silos
- Silo A: MTG, HappyHomarid, CollectorsCoast.
- Silo B: Amplissa and adult.

No shared assets, credentials, prompts, datasets, or automation runs between silo A and silo B.

## Guardrails
1. No public action without explicit approval record.
2. No cross-silo copy, sync, or merge.
3. No unknown script execution from untrusted paths.
4. No manual deletions of operating records; archive then replace.
5. No silent launcher exits; keep shell open for review.

## Required controls
- separate root folders by silo
- separate ledgers by silo
- separate credentials by silo
- separate proof directories by silo
- explicit approval file for public actions

## Incident protocol
If silo breach is suspected:
1. freeze affected automation,
2. capture proof and logs,
3. rotate credentials,
4. run boundary audit,
5. resume only after written clearance.
