"""Example automation task showing the three new Cortex capabilities.

The script simulates a deck primer generation job. It demonstrates:
- recording a change entry in the change journal
- pausing for approval when confidence is low or the action is risky
- emitting a structured self-explanation

This sample is safe to run repeatedly and is designed to be adapted by other jobs.
"""
from __future__ import annotations

from cortex import ChangeJournal, ExplanationWriter, GovernanceContext, GovernanceGate


def run_deck_primer_job(confidence: float = 0.6) -> None:
    job_name = "deck_primer"
    governance = GovernanceGate()
    journal = ChangeJournal()
    explanations = ExplanationWriter()

    context = GovernanceContext(
        job_name=job_name,
        confidence=confidence,
        touches_money=False,
        overwrites_files=True,
        deletes_data=False,
        changes_behavior=True,
        summary="Primer generation would overwrite cached primer files.",
        metadata={"target_list": "standard-tier-1"},
    )

    # Ask for approval when confidence is low or the operation is risky.
    if governance.guard(context):
        journal.log_no_material_change(module=job_name)
        return

    # Simulate a change being applied.
    journal.log_change(
        module=job_name,
        changed_item="primer files refreshed",
        change_category="file",
        approval="auto",
        auto_applied=True,
    )

    # Write the explanation describing why the decision was safe.
    explanations.write(
        job_name=job_name,
        job_type="primer_generation",
        input_summary="Collected metagame stats and decklists for weekly update",
        decision="Regenerated primers and updated cached docs",
        risk_level="medium",
        confidence=confidence,
        human_summary=(
            "The primer generator refreshed cached deck write-ups using the latest data. "
            "No payouts were triggered, but files were overwritten after governance checks."
        ),
        metadata={"primer_count": 12},
    )


if __name__ == "__main__":
    run_deck_primer_job()
