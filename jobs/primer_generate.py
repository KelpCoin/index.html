from pathlib import Path
from typing import Dict

from change_journal import ChangeJournal
from explanation_writer import ExplanationWriter
from file_utils import SafeFileManager
from governance import GovernanceException, GovernanceGate
from rollback_engine import RollbackEngine
from supervisor import SupervisorNotifier
from build_bot.primer_pipeline import PrimerPipeline


def run(gate: GovernanceGate, journal: ChangeJournal, explanations: ExplanationWriter, rollback: RollbackEngine, supervisor: SupervisorNotifier) -> None:
    deck_path = Path("data/decks/sample_deck.json")
    output_dir = Path("artifacts/primers")
    output_dir.mkdir(parents=True, exist_ok=True)
    pipeline = PrimerPipeline(gate, journal, rollback)

    if not deck_path.exists():
        journal.log_no_material_change("primer_generate", "Deck file missing", {"deck": str(deck_path)})
        return

    try:
        primer_markdown, metadata = pipeline.generate(deck_path)
    except GovernanceException as exc:
        journal.log_no_material_change("primer_generate", "Pending approval before primer generation", {"reason": str(exc)})
        return

    output_file = output_dir / f"{metadata['deck_name'].replace(' ', '_').lower()}.md"
    manager = SafeFileManager(gate, journal, rollback, supervisor)
    try:
        manager.write_text(
            output_file,
            primer_markdown,
            action="overwrite",
            description=f"Generated primer for deck {metadata['deck_name']}",
            risk_level="high" if output_file.exists() else "standard",
        )
    except GovernanceException as exc:
        journal.log_no_material_change("primer_generate", "Approval required before writing primer", {"reason": str(exc)})
        return

    explanations.write(
        "primer_generate",
        f"Primer generated for deck {metadata['deck_name']}.",
        [
            f"Deck source: {deck_path}",
            f"Primer output: {output_file}",
            "Governance check enforced prior to writing",
            "Rollback versions previous primer before overwrite",
        ],
        metadata=metadata,
    )
