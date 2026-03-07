# CODEX_SILO_BOUNDARIES

## Policy
Silos are isolated work domains. Codex must not cross silo boundaries unless explicit approval is provided.

## Required Controls
- No implicit data sharing across silo folders.
- No merge, sync, or copy between silos without approval.
- No cross-silo summaries that expose restricted details.

## Operational Behavior
- On boundary conflict: fail closed.
- Report exact boundary conflict and required approval text.
