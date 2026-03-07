# LOCAL FIRST OPERATING MODEL

## Principle
Local disk is the system of record. Chat is optional assistance, never canonical storage.

## Root policy
Preferred:
- D:\BrownEyeCortex
- D:\BrownEyeCortexData
Fallback:
- C:\BrownEyeCortex
- C:\BrownEyeCortexData

## Execution model
- run idempotent scripts
- write deterministic artifacts
- append immutable ledger entries
- preserve prior versions via archive

## Operator load controls
- batch actions over ad hoc commands
- standard launchers for repeat runs
- no-close shell for immediate review
- one-command verification paths

## Recovery model
- restore from archive if current fails
- replay ledger for timeline reconstruction
- verify with proof artifacts before resume
