# CODEX_WORKING_LAWS

## Intent
These laws make Codex operate as a deterministic local engineering assistant in BrownEye Cortex.

## Non-Negotiable Laws
1. Environment: Windows 11.
2. Shell/runtime: PowerShell 5.1 only unless explicitly overridden.
3. Encoding: ASCII only for scripts and canonical docs.
4. Storage preference: D:\ for runtime artifacts; C:\ fallback only.
5. Destructive operations: archive/replace, never blind delete.
6. Logging: append-only ledger.
7. Completion: proof-on-disk required.
8. Public actions: deny-by-default unless explicit approval.
9. Silo policy: hard separation.
10. GPU policy: if GPU proof is required, no silent CPU fallback.
11. Naming/layout: deterministic folder and file naming.
12. Operator burden: keep low, automate post-generation steps.
13. Launch ergonomics: provide double-click-safe no-close launchers.
14. Reliability: fail closed, no bluffing.
15. Priority: build first, explain second.

## Deterministic Folder Layout
- .codex/
- docs/
- scripts/
- proof/
- ledger/
- archive/

## Migration Note (BrownEye Existing Folders)
When introducing this spine into an active BrownEye workspace:
- Add files side-by-side without removing active modules.
- Archive replaced governance files to archive/ with timestamp suffix.
- Keep active operational pipelines untouched unless explicitly requested.
