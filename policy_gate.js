/**
 * Policy Gate evaluates arbitrage alert candidates against guardrails.
 *
 * INPUT:
 * {
 *   signal: {...},
 *   ranker_score: float,
 *   shadow_judge_agreement_rate_30d: float
 * }
 *
 * OUTPUT:
 * {
 *   decision: 'allow' | 'hold',
 *   confidence: number (0-1)
 * }
 */

function isNumber(value) {
  return typeof value === 'number' && Number.isFinite(value);
}

function clamp01(value) {
  return Math.max(0, Math.min(1, value));
}

function computeConfidence(input) {
  const metrics = [
    input && input.ranker_score,
    input && input.shadow_judge_agreement_rate_30d,
  ].filter(isNumber);

  if (metrics.length === 0) return 0;

  return clamp01(Math.min(...metrics.map(clamp01)));
}

function policyGate(input) {
  const rankerScore = input?.ranker_score;
  const shadowAgreement = input?.shadow_judge_agreement_rate_30d;

  const hasRanker = isNumber(rankerScore);
  const hasShadow = isNumber(shadowAgreement);

  const confidence = computeConfidence(input);

  let decision = 'hold';

  if (
    hasRanker &&
    hasShadow &&
    rankerScore >= 0.6 &&
    shadowAgreement >= 0.55 &&
    confidence >= 0.4
  ) {
    decision = 'allow';
  }

  return { decision, confidence };
}

function runSelfCheck() {
  const scenarios = [
    {
      name: 'Missing required metrics defaults to hold',
      input: { signal: {} },
      expected: { decision: 'hold', confidence: 0 },
    },
    {
      name: 'Fails thresholds when ranker below minimum',
      input: {
        signal: {},
        ranker_score: 0.4,
        shadow_judge_agreement_rate_30d: 0.8,
      },
      expected: { decision: 'hold', confidence: 0.4 },
    },
    {
      name: 'Fails thresholds when shadow judge below minimum',
      input: {
        signal: {},
        ranker_score: 0.8,
        shadow_judge_agreement_rate_30d: 0.4,
      },
      expected: { decision: 'hold', confidence: 0.4 },
    },
    {
      name: 'Confidence guard forces hold even when scores pass',
      input: {
        signal: {},
        ranker_score: 0.7,
        shadow_judge_agreement_rate_30d: 0.4,
      },
      expected: { decision: 'hold', confidence: 0.4 },
    },
    {
      name: 'Allows when all policies are satisfied',
      input: {
        signal: {},
        ranker_score: 0.7,
        shadow_judge_agreement_rate_30d: 0.8,
      },
      expected: { decision: 'allow', confidence: 0.7 },
    },
  ];

  let passed = 0;

  scenarios.forEach((scenario) => {
    const result = policyGate(scenario.input);
    const matchesDecision = result.decision === scenario.expected.decision;
    const matchesConfidence = Math.abs(result.confidence - scenario.expected.confidence) < 1e-9;

    if (matchesDecision && matchesConfidence) {
      passed += 1;
    } else {
      console.error('Scenario failed:', scenario.name);
      console.error('Expected:', scenario.expected, 'Received:', result);
      process.exitCode = 1;
    }
  });

  if (passed === scenarios.length) {
    console.log(`All ${passed} policy gate scenarios passed.`);
  }
}

if (require.main === module) {
  runSelfCheck();
}

module.exports = { policyGate, computeConfidence, clamp01, isNumber };
