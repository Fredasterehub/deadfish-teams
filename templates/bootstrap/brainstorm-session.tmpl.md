# Brainstorm Session Template

Target file: `tracks/<track_id>/BRAINSTORM_SESSION.md`

Use this structure to keep ideation auditable and reusable.

## Session Meta

```yaml
session:
  track_id: "<track_id>"
  mode: "INTERACTIVE|DRAFT-FIRST"
  status: "in_progress|converged|paused"
  started_at: "<ISO-8601>"
  updated_at: "<ISO-8601>"
  facilitator: "brainstormer"
  participants:
    - "<name or role>"
  objective: "<one-sentence objective>"
  constraints:
    - "<constraint>"
  success_criteria:
    - "<criterion>"
  non_goals:
    - "<explicit non-goal>"
  assumptions:
    - id: "A01"
      text: "<assumption>"
      status: "open|confirmed|rejected"
```

## Round Log

Track what happened each round, including diversity metrics.

```yaml
rounds:
  - round_id: "R01"
    intent: "discover|diverge|converge|review"
    technique: "<technique used>"
    domain: "<focus domain>"
    prompts_used:
      - "<prompt>"
    ideas_added: ["I001", "I002"]
    notes: "<key observations>"
    metrics:
      total_ideas: 2
      unique_domains: 1
      unique_techniques: 1
```

## Idea Ledger (Append-Only)

```yaml
ideas:
  - id: "I001"
    title: "<short title>"
    description: "<one-line idea summary>"
    novelty: "<how it differs from obvious alternatives>"
    source_technique: "<technique>"
    source_round: "R01"
    source_domain: "<domain>"
    status: "active|parked|merged|dropped"
```

## Theme Clusters

Every active idea must appear in at least one theme.

```yaml
themes:
  - id: "T01"
    name: "<theme name>"
    summary: "<theme explanation>"
    member_ideas: ["I001", "I004"]
    priority: "Must|Should|Could|Won't"
    risk: "<major risk>"
```

## Convergence Quality Gates

Warn if gates fail. Convergence is allowed only after pass or explicit override.

```yaml
quality_gates:
  divergence:
    min_total_ideas: 12
    min_unique_domains: 3
    min_unique_techniques: 3
    status: "pass|warn"
    evidence: "<counts and notes>"
  coverage:
    active_ideas_mapped_to_theme: true
    status: "pass|warn"
    evidence: "<mapping notes>"
  decision_readiness:
    has_tradeoff_table: true
    has_recommendation_and_fallback: true
    status: "pass|warn"
    evidence: "<notes>"
  override:
    used: false
    reason: "<required when used>"
    approved_by: "<human approver>"
```

## Requirement Traceability Draft

Link requirements back to themes and ideas before writing `REQUIREMENTS.md`.

```yaml
requirement_traceability:
  - requirement_id: "<CAT-01>"
    text: "<requirement text>"
    source_themes: ["T01"]
    source_ideas: ["I001", "I004"]
    confidence: "high|medium|low"
```

## Candidate Task Seeds

```yaml
task_candidates:
  - task_id: "<track_id>-P1-T01"
    title: "<task title>"
    source_requirements: ["<CAT-01>"]
    source_themes: ["T01"]
    source_ideas: ["I001"]
```
