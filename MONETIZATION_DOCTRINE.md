# Monetization Doctrine

## Objective
Convert intent to payment with minimal friction and hard measurement.

## Binding rules
- Never run growth work without an active payment surface.
- Every campaign must map to a specific payment endpoint.
- If intent spikes and payment path fails, treat as critical incident.
- Build payment surfaces before content scale.

## Payment surface requirements
- Clear offer
- Price and terms visible
- Fast checkout path
- Confirmation proof path
- Ledger capture of transaction signals

## Paid signal thresholds
- Stage 0: no paid events -> do not scale
- Stage 1: first paid events -> stabilize fulfillment and tracking
- Stage 2: repeat paid events -> small controlled scale
- Stage 3: stable paid conversion -> broaden channels

## Winner and loser handling
- Winners: copy structure and process quickly.
- Losers: cut spend, archive experiment, record reason.

## Minimum daily monetization checks
1. Are payment links live?
2. Can buyer pay in under 2 minutes?
3. Is fulfillment path documented?
4. Is paid signal in ledger today?
5. Is there a blocker at intent peak?
