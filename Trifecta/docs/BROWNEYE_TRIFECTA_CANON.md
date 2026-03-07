# BrownEye Trifecta Canon

## Purpose
BrownEye Trifecta is a local decision primitive for scoring ideas, offers, prompts, modules, and decisions.
It converts three structured signals into a binding verdict with ledger and proof traces.

## Three signals

### Signal A (opportunity)
Signal A captures upside potential.
It represents execution gain, strategic upside, leverage, or favorable market pull.
It is scored by strength, confidence, and evidence.

### Signal B (adversarial)
Signal B captures failure pressure.
It represents risk, sabotage surface, fragility, constraints, legal exposure, and downside likelihood.
It is scored by strength, confidence, and evidence.

### Signal C (triangulation)
Signal C is a third operator, not a tie-breaker.
It actively reshapes interpretation of A and B through one mode:
- SHARPEN: tighten estimate quality
- RESOLVE: settle a conflict by weighting validated direction
- DISAMBIGUATE: remove ambiguity from mixed evidence
- VETO: enforce fail-fast suppression

Signal C also sets orientation:
- POSITIVE
- NEGATIVE
- NEUTRAL

Signal C can set veto=true to trigger quarantine or kill even when A appears favorable.

## Why C is not a tie-breaker
A tie-breaker only chooses when two sides are close.
Signal C can override, amplify, or suppress outcomes regardless of tie state.
It acts as a structural control signal, not a voting token.

## Difference from pros and cons
Pros/cons lists are descriptive and non-binding.
Trifecta is machine-usable and deterministic:
- strict schema
- normalized scores
- verdict thresholds
- append-only ledger events
- persistent proof records

## Verdicts
- SHIP: approved for active deployment
- HOLD: paused pending evidence, tests, or revisions
- QUARANTINE: isolate from production pathways
- KILL: reject and terminate further investment

## Binding behavior in BrownEye Cortex
When Trifecta is invoked by BrownEye Cortex and returns a verdict, that verdict is binding for the evaluated object within that execution context.
Overrides require a new packet with new evidence and a new ledger event.

## Storage model
- Packets: deterministic id from content hash
- Scores: structured json per packet id
- Reports: structured and text outputs
- Ledger: append-only jsonl events
- Proof: install and verification records

## Operating constraints
- Target platform: Windows 11
- Shell: PowerShell 5.1 compatible scripts
- Character set: ASCII only
- Preferred root: D:\BrownEye\Trifecta
