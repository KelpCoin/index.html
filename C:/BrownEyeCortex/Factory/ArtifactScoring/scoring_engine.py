"""
Artifact scoring engine for BrownEye Cortex.

This module evaluates artifacts across multiple independent axes and
produces a structured scorecard that downstream systems can use.
All scoring logic is intentionally lightweight and deterministic so it can
run in constrained environments without external dependencies.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Iterable, Tuple


# Constants
AXES: Tuple[str, ...] = (
    "council_quality",
    "clarity",
    "risk",
    "persuasiveness",
    "market_potential",
    "audience_fit",
    "originality",
    "operational_cost_inverse",
    "recurrence_value",
    "legal_risk_inverse",
)

WEIGHTS: Dict[str, float] = {
    "council_quality": 0.30,
    "clarity": 0.15,
    "market_potential": 0.20,
    "audience_fit": 0.15,
    "operational_cost_inverse": 0.10,
    "legal_risk_inverse": 0.10,
}


@dataclass
class AxisContext:
    """Context used while deriving stubbed axis scores.

    Attributes:
        artifact_text: Raw textual content of the artifact.
        artifact_type: Short descriptor for the artifact kind.
    """

    artifact_text: str
    artifact_type: str

    def density(self) -> float:
        """Return a simple density heuristic (words per 100 characters)."""

        if not self.artifact_text:
            return 0.0
        word_count = len(self.artifact_text.split())
        char_count = max(len(self.artifact_text), 1)
        return (word_count / char_count) * 100

    def keyword_score(self, keywords: Iterable[str]) -> float:
        """Return proportional keyword hit rate scaled to a 0-10 range."""

        if not self.artifact_text:
            return 0.0
        lower_text = self.artifact_text.lower()
        hits = sum(1 for term in keywords if term.lower() in lower_text)
        return clamp((hits / max(len(tuple(keywords)), 1)) * 10)


# Utility helpers

def clamp(value: float, low: float = 0.0, high: float = 10.0) -> float:
    """Clamp value to an inclusive [low, high] range."""

    return max(low, min(high, value))


def normalized_length_score(text: str) -> float:
    """Return a lightweight score based on artifact length.

    The function favors artifacts between 200 and 1200 characters and
    penalizes extremely short or long submissions.
    """

    length = len(text)
    if length == 0:
        return 0.0
    ideal_min, ideal_max = 200, 1200
    if ideal_min <= length <= ideal_max:
        return 10.0
    if length < ideal_min:
        return clamp((length / ideal_min) * 10)
    # For long artifacts, linearly decay after the ideal max
    overage_ratio = (length - ideal_max) / max(ideal_max, 1)
    return clamp(10.0 - overage_ratio * 5)


def derive_stub_axes(context: AxisContext) -> Dict[str, float]:
    """Generate deterministic stub scores for each axis when no council data is provided."""

    text = context.artifact_text
    density_score = clamp(context.density())
    length_score = normalized_length_score(text)

    axes: Dict[str, float] = {
        "clarity": (density_score + length_score) / 2,
        "risk": clamp(10.0 - density_score / 2),
        "persuasiveness": clamp(length_score * 0.8 + context.keyword_score(["value", "impact", "benefit"]))
        ,
        "market_potential": clamp(context.keyword_score(["market", "revenue", "growth", "customers"]) + length_score / 4),
        "audience_fit": clamp(context.keyword_score([context.artifact_type]) + density_score / 2),
        "originality": clamp(7.0 + context.keyword_score(["novel", "unique", "first"]) / 2),
        "operational_cost_inverse": clamp(5.0 + context.keyword_score(["efficient", "automate", "optimize"]) / 2),
        "recurrence_value": clamp(context.keyword_score(["subscription", "repeat", "retention"]) + length_score / 5),
        "legal_risk_inverse": clamp(6.0 + context.keyword_score(["compliant", "safe", "consent"]) / 2),
    }

    # council_quality is derived using clarity and persuasiveness as a proxy when not provided
    axes["council_quality"] = clamp((axes["clarity"] + axes["persuasiveness"]) / 2)

    return axes


def merge_council_axes(stub_axes: Dict[str, float], metadata: Dict | None) -> Dict[str, float]:
    """Merge council-provided axis scores into stub axes when available."""

    if not metadata:
        return stub_axes

    council_scores = metadata.get("council_scores") or {}
    merged = dict(stub_axes)
    for axis, value in council_scores.items():
        if axis in AXES:
            merged[axis] = clamp(float(value))
    return merged


def compute_composite_score(axes: Dict[str, float]) -> float:
    """Compute weighted composite score using the required formula."""

    composite = 0.0
    for axis, weight in WEIGHTS.items():
        composite += weight * axes.get(axis, 0.0)
    return round(composite, 2)


def determine_verdict(composite_score: float) -> str:
    """Translate composite score into a verdict label."""

    if composite_score >= 8.0:
        return "publish"
    if composite_score >= 5.0:
        return "improve"
    return "scrap"


# Public API

def score_artifact(
    artifact_text: str,
    artifact_type: str,
    metadata: Dict | None = None,
) -> Dict:
    """Score an artifact across multiple axes and return a structured scorecard.

    Args:
        artifact_text: Raw textual representation of the artifact.
        artifact_type: Descriptor such as "pitch", "proposal", or "brief" that
            influences audience fit and keyword matching.
        metadata: Optional dictionary containing council-provided axis scores
            under the key ``"council_scores"``. Any supplied axis score is clamped
            to the 0-10 range and overrides stubbed values.

    Returns:
        Dictionary with the following keys:
        - ``axes``: mapping of axis names to numeric scores.
        - ``flags``: currently an empty list reserved for future rule-based flags.
        - ``composite_score``: weighted composite score rounded to two decimals.
        - ``verdict``: one of ``"publish"``, ``"improve"``, or ``"scrap"`` based on thresholds.
    """

    context = AxisContext(artifact_text=artifact_text, artifact_type=artifact_type)
    stub_axes = derive_stub_axes(context)
    axes = merge_council_axes(stub_axes, metadata)
    composite_score = compute_composite_score(axes)
    verdict = determine_verdict(composite_score)

    return {
        "axes": axes,
        "flags": [],
        "composite_score": composite_score,
        "verdict": verdict,
    }


# Example usage (for quick manual verification):
# example_result = score_artifact(
#     artifact_text="""
#     This proposal details a novel subscription-based analytics platform.
#     It emphasizes customer retention, market growth, and operational automation
#     to deliver meaningful revenue impact while staying compliant with safety standards.
#     """,
#     artifact_type="proposal",
#     metadata={"council_scores": {"council_quality": 8.5}},
# )
# print(example_result)
