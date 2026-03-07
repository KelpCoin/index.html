# BrownEye Bus Migration Note

Goal: move existing BrownEye modules from ad hoc scripts and chat state to cartridge-driven local automation.

## Phase 1: Envelope and Submission
- Keep current module code.
- Wrap each module input as a universal cartridge JSON.
- Use Submit_BusCartridge.ps1 so operators do not hand-edit JSON.
- Start tagging every cartridge with silo and silo_tags.

## Phase 2: Processing Adapter
- Add a thin adapter in each module that reads from Bus/done or Bus/processing.
- Map module-specific fields from payload.
- Keep existing module logic unchanged.

## Phase 3: Approval and Safety Gate
- Mark public or risky actions with payload.visibility=public or risk_flags.
- Require approval object with status=approved before execution.
- Route any missing approval or schema violations to quarantine.

## Phase 4: Proof and Verifier Integration
- Emit module proof artifact into Bus/proof/processed.
- Submit verifier_requests cartridges for second-pass checks.
- Store all bus transitions in append-only bus_events.jsonl.

## Phase 5: Full Cartridge Native
- Replace direct script-to-script calls with cartridge handoffs.
- Preserve archive-not-delete policy in done and quarantine.
- Add new local agents by giving them read/write access to bus folders and schemas.

This path allows progressive adoption without breaking current BrownEye workflows.
