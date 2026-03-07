# Money Signals and Triangulation

## Purpose
Avoid false confidence by triangulating demand through multiple hard signals.

## Signal stack
1. Payment signal (strongest)
2. Qualified intent signal
3. Fulfillment completion signal

## Triangulation rules
- Do not trust a single vanity metric.
- Require alignment between payment and fulfillment.
- Treat conflicting signals as investigation trigger.

## Ledger event schema guidance
- event_type
- timestamp_utc
- silo
- offer_id
- channel
- amount
- status
- proof_path

## Decisions
- Scale only when payment plus fulfillment signals are stable.
- Pause when payment drops or fulfillment error rises.
- Retire offers with repeated negative unit economics.
