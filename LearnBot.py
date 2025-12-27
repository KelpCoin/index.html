'''
LearnBot: analyze pricing and arbitrage results to tune marketplace preferences and risk rules.

Usage: python LearnBot.py [--prices prices.jsonl] [--arbitrage Arbitrage_Results.csv]

Outputs a human-readable log to logs/learnbot.log and writes structured
suggestions to the path requested by stakeholders:
C:\\BrownEyeCortex\\Logs\\Arbitrage\\Tuning\\learn_suggestions.json
'''
from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from statistics import mean
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

WINDOWS_SUGGESTION_PATH = Path('C:/BrownEyeCortex/Logs/Arbitrage/Tuning/learn_suggestions.json')
LOG_PATH = Path('logs/learnbot.log')


@dataclass
class SpreadPoint:
    card: str
    category: str
    marketplace: str
    spread: float
    volume: float
    timestamp: float
    source: str


@dataclass
class TrendSignal:
    key: str
    trend: float
    confidence: float
    direction: str
    sample_size: int
    rationale: str


@dataclass
class Suggestion:
    preferred_marketplaces: Dict[str, List[str]]
    margin_thresholds: Dict[str, float]
    penalty_weights: Dict[str, float]
    confidence_flags: Dict[str, float]
    rationale: List[str] = field(default_factory=list)


def ensure_dirs() -> None:
    WINDOWS_SUGGESTION_PATH.parent.mkdir(parents=True, exist_ok=True)
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)


def read_prices(path: Path) -> List[SpreadPoint]:
    points: List[SpreadPoint] = []
    if not path.exists():
        return points
    with path.open() as f:
        for line_no, line in enumerate(f, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                log(f'Skipping malformed JSONL line {line_no} in {path}')
                continue
            card = str(payload.get('card') or payload.get('name') or 'unknown')
            category = str(payload.get('category') or payload.get('type') or 'uncategorized')
            marketplace = str(payload.get('marketplace') or payload.get('exchange') or 'unknown')
            spread = compute_spread(payload)
            volume = float(payload.get('volume') or payload.get('liquidity') or 0.0)
            timestamp = float(payload.get('timestamp') or payload.get('ts') or line_no)
            points.append(
                SpreadPoint(
                    card=card,
                    category=category,
                    marketplace=marketplace,
                    spread=spread,
                    volume=volume,
                    timestamp=timestamp,
                    source='prices.jsonl',
                )
            )
    return points


def read_arbitrage(path: Path) -> List[SpreadPoint]:
    points: List[SpreadPoint] = []
    if not path.exists():
        return points
    with path.open(newline='') as f:
        reader = csv.DictReader(f)
        for line_no, row in enumerate(reader, start=2):
            card = row.get('card') or row.get('name') or 'unknown'
            category = row.get('category') or row.get('type') or 'uncategorized'
            marketplace = row.get('marketplace') or row.get('exchange') or 'unknown'
            spread = parse_float(row, ['spread', 'margin', 'pnl'], default=0.0)
            if spread == 0.0:
                spread = compute_spread(row)
            volume = parse_float(row, ['volume', 'filled', 'liquidity'], default=0.0)
            timestamp = parse_float(row, ['timestamp', 'ts', 'epoch'], default=line_no)
            points.append(
                SpreadPoint(
                    card=str(card),
                    category=str(category),
                    marketplace=str(marketplace),
                    spread=spread,
                    volume=volume,
                    timestamp=timestamp,
                    source='Arbitrage_Results.csv',
                )
            )
    return points


def parse_float(row: Dict[str, str], keys: Sequence[str], default: float = 0.0) -> float:
    for key in keys:
        if key in row and row[key] not in (None, ''):
            try:
                return float(row[key])
            except ValueError:
                continue
    return default


def compute_spread(payload: Dict[str, object]) -> float:
    '''Compute spread from possible price fields. Positive means opportunity.'''
    for buy_key, sell_key in [('buy_price', 'sell_price'), ('bid', 'ask'), ('bid_price', 'ask_price')]:
        if buy_key in payload and sell_key in payload:
            try:
                buy = float(payload[buy_key])
                sell = float(payload[sell_key])
                return sell - buy
            except (TypeError, ValueError):
                continue
    if 'spread' in payload:
        try:
            return float(payload['spread'])
        except (TypeError, ValueError):
            return 0.0
    return 0.0


def trend_by_key(points: Iterable[SpreadPoint], key_func) -> List[TrendSignal]:
    signals: List[TrendSignal] = []
    grouped: Dict[str, List[SpreadPoint]] = defaultdict(list)
    for pt in points:
        grouped[key_func(pt)].append(pt)

    for key, entries in grouped.items():
        entries.sort(key=lambda p: p.timestamp)
        if len(entries) < 6:
            signals.append(
                TrendSignal(
                    key=key,
                    trend=0.0,
                    confidence=0.0,
                    direction='flat',
                    sample_size=len(entries),
                    rationale='Not enough observations for a confident trend.',
                )
            )
            continue

        mid = len(entries) // 2
        early_window = entries[:mid]
        recent_window = entries[mid:]
        early_avg = mean(pt.spread for pt in early_window)
        recent_avg = mean(pt.spread for pt in recent_window)
        change = recent_avg - early_avg
        direction = 'improving' if change > 0 else 'deteriorating' if change < 0 else 'flat'
        volatility = max(0.5, abs(early_avg) + abs(recent_avg))
        confidence = min(1.0, len(entries) / 20) * min(1.0, abs(change) / volatility)
        rationale = (
            f'avg spread moved from {early_avg:.4f} to {recent_avg:.4f}; change={change:.4f}; '
            f'n={len(entries)}'
        )
        signals.append(
            TrendSignal(
                key=key,
                trend=change,
                confidence=confidence,
                direction=direction,
                sample_size=len(entries),
                rationale=rationale,
            )
        )
    return signals


def select_marketplace_preferences(signals: List[TrendSignal], min_conf: float = 0.35) -> Tuple[List[str], List[str], Dict[str, float]]:
    improve = [s for s in signals if s.direction == 'improving' and s.confidence >= min_conf]
    worsen = [s for s in signals if s.direction == 'deteriorating' and s.confidence >= min_conf]
    improve_sorted = sorted(improve, key=lambda s: (s.confidence, s.trend), reverse=True)
    worsen_sorted = sorted(worsen, key=lambda s: (s.confidence, abs(s.trend)), reverse=True)
    return (
        [s.key for s in improve_sorted[:5]],
        [s.key for s in worsen_sorted[:5]],
        {s.key: s.confidence for s in improve_sorted + worsen_sorted},
    )


def suggest_margins(category_signals: List[TrendSignal], base_threshold: float = 0.02, min_conf: float = 0.35) -> Tuple[Dict[str, float], Dict[str, float]]:
    adjustments: Dict[str, float] = {}
    conf: Dict[str, float] = {}
    for sig in category_signals:
        if sig.confidence < min_conf:
            continue
        delta = 0.0
        if sig.direction == 'improving':
            delta = min(0.03, sig.trend * 0.25)
        elif sig.direction == 'deteriorating':
            delta = max(-0.03, sig.trend * 0.25)
        adjustments[sig.key] = round(base_threshold + delta, 4)
        conf[sig.key] = sig.confidence
    return adjustments, conf


def suggest_penalties(card_signals: List[TrendSignal], volume_lookup: Dict[str, float], min_conf: float = 0.35) -> Tuple[Dict[str, float], Dict[str, float]]:
    penalties: Dict[str, float] = {}
    conf: Dict[str, float] = {}
    low_volume_threshold = max(1.0, mean(volume_lookup.values()) if volume_lookup else 1.0)
    for sig in card_signals:
        if sig.confidence < min_conf:
            continue
        volume = volume_lookup.get(sig.key, 0.0)
        if volume <= low_volume_threshold:
            base_penalty = 1.1
            adjustment = 0.15 if sig.direction == 'deteriorating' else -0.05
            penalties[sig.key] = round(base_penalty + adjustment, 3)
            conf[sig.key] = sig.confidence
    return penalties, conf


def aggregate_volume(points: Iterable[SpreadPoint], key_func) -> Dict[str, float]:
    totals: Dict[str, float] = defaultdict(float)
    for pt in points:
        totals[key_func(pt)] += pt.volume
    return totals


def log(message: str) -> None:
    ensure_dirs()
    timestamp = datetime.utcnow().isoformat()
    with LOG_PATH.open('a', encoding='utf-8') as fh:
        fh.write(f'[{timestamp}] {message}\n')


def build_suggestions(points: List[SpreadPoint]) -> Suggestion:
    market_signals = trend_by_key(points, lambda p: p.marketplace)
    category_signals = trend_by_key(points, lambda p: p.category)
    card_signals = trend_by_key(points, lambda p: p.card)

    preferred_up, preferred_down, market_conf = select_marketplace_preferences(market_signals)
    margin_thresholds, margin_conf = suggest_margins(category_signals)

    volume_by_card = aggregate_volume(points, lambda p: p.card)
    penalty_weights, penalty_conf = suggest_penalties(card_signals, volume_by_card)

    combined_conf = {**market_conf, **margin_conf, **penalty_conf}
    rationale = [sig.rationale for sig in market_signals + category_signals if sig.confidence > 0]

    return Suggestion(
        preferred_marketplaces={'increase': preferred_up, 'decrease': preferred_down},
        margin_thresholds=margin_thresholds,
        penalty_weights=penalty_weights,
        confidence_flags=combined_conf,
        rationale=rationale,
    )


def write_suggestions(suggestion: Suggestion) -> None:
    ensure_dirs()
    payload = {
        'generated_at': datetime.utcnow().isoformat(),
        'preferred_marketplaces': suggestion.preferred_marketplaces,
        'margin_thresholds': suggestion.margin_thresholds,
        'penalty_weights': suggestion.penalty_weights,
        'confidence_flags': suggestion.confidence_flags,
        'rationale': suggestion.rationale,
    }
    WINDOWS_SUGGESTION_PATH.write_text(json.dumps(payload, indent=2), encoding='utf-8')


def main(prices_path: Path, arbitrage_path: Path, dry_run: bool = False) -> None:
    points = read_prices(prices_path) + read_arbitrage(arbitrage_path)
    if not points:
        log('No data available. Suggestions not updated to avoid overfitting.')
        return

    suggestion = build_suggestions(points)
    log(
        'Prepared suggestions with counts: '
        f"markets={len(suggestion.preferred_marketplaces['increase']) + len(suggestion.preferred_marketplaces['decrease'])}, "
        f'categories={len(suggestion.margin_thresholds)}, cards={len(suggestion.penalty_weights)}'
    )

    if not suggestion.confidence_flags:
        log('Confidence too low across the board; skipping persistence to avoid overfitting.')
        return

    if not dry_run:
        write_suggestions(suggestion)
        log(f'Suggestions written to {WINDOWS_SUGGESTION_PATH}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='LearnBot tuning assistant')
    parser.add_argument('--prices', type=Path, default=Path('prices.jsonl'), help='Path to prices.jsonl')
    parser.add_argument('--arbitrage', type=Path, default=Path('Arbitrage_Results.csv'), help='Path to Arbitrage_Results.csv')
    parser.add_argument('--dry-run', action='store_true', help='Calculate suggestions without writing outputs')
    args = parser.parse_args()
    main(args.prices, args.arbitrage, dry_run=args.dry_run)
