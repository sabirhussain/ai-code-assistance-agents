---
name: nw-unit-test-reviewer
description: Finding taxonomy and severity scale, KB-rule-to-violation-signature map, review report schema, and KB-edit governance rule for reviewing generated JUnit tests against production code, tech-stack context, test-strategy.yaml, and test-review-kb.yaml.
user-invocable: false
disable-model-invocation: true
---

# Unit Test Reviewer — Domain Knowledge

## Finding Taxonomy

Every finding belongs to exactly one category:

| Category | Definition |
|----------|------------|
| `traceability` | A test method has no corresponding item in the strategy entry (filler/coverage-padding), or a strategy item's coverage cannot be traced to any test method. |
| `coverage_gap` | A named strategy item (behavior, branch, boundary, exceptional case, argument-captor opportunity) has no corresponding test anywhere in the file. |
| `behavior_drift` | The test asserts something that no longer matches the production class's current, freshly-read source — the class changed since the strategy/test was written. |
| `kb_violation` | The test violates a specific `enabled: true` KB rule. Always cites the rule ID. |
| `exclusion_violation` | The generator added a test for something the strategy's `excluded_tests` explicitly excluded, or a listed exclusion should not have been excluded. |
| `quality_signal` | A general test-quality issue not owned by any existing TR-0xx rule (non-deterministic assertion, missing assertion on a stubbed path, a test that passes even when the production code is wrong). Candidate for `kb_gap_assessment`. |
| `execution_failure` | A real, ground-truth test failure reported in `.ai-test-engineer/verify/build-verification.yaml`'s `failures[]` for a test method belonging to this class. Always confirmed, never a false positive, and always forces `verdict: revisions_needed` regardless of every other angle's result. |

## Ground-Truth Precedence Rule

When `.ai-test-engineer/verify/build-verification.yaml` exists and lists a failure under `failures[]` for a test method in the class under review, record one `execution_failure` finding per failing test — severity always `high`, `evidence` the exact `reason` string from that file. This finding is never discarded by the reflection pass (Section 4); reflection may only add cross-referenced context (e.g. which production line the failure likely traces to), never remove it. `verdict` is `revisions_needed` whenever at least one `execution_failure` finding exists, even if every other evaluation angle came back clean. This agent does not judge whether the failure traces to a test defect or a genuine production-behavior mismatch — it reports the failure and routes that judgment (and any escalation) to `nw-unit-test-issue-fixer` via the finding's `recommendation`. When `build-verification.yaml` is absent (e.g. a standalone review run before any build-verify has ever executed), proceed with static-only review as before — nothing forces `revisions_needed` from a source that does not exist yet.

## Severity Scale

| Severity | Meaning | Examples |
|----------|---------|----------|
| `high` | Test would pass while masking wrong behavior, or a critical branch/exception path has zero coverage, or the test actually fails when run for real. | Missing exceptional-case test; assertion that can't fail; drift where test no longer matches source; any `execution_failure` finding (always `high`). |
| `medium` | Test works but violates a medium-severity KB rule, or misses a real quality opportunity (parameterization, captor). | TR-001/TR-003/TR-004/TR-007 violations; a real coverage_gap on a non-critical branch. |
| `low` | Style/efficiency issue with no correctness risk. | TR-006 violations; minor traceability nit (an extra, harmless but redundant test). |

## KB-Rule-to-Violation-Signature Map

Use these signatures to detect each rule's violation in a generated test file. Only apply a signature if its rule is confirmed `enabled: true` this run.

| Rule | Violation Signature |
|------|---------------------|
| TR-001 (spy misuse) | `Mockito.spy(` or `@Spy` used where the test never exercises the real partial behavior it exists for — a plain `@Mock` would suffice. |
| TR-002 (reflection into private methods) | `.setAccessible(true)`, `getDeclaredMethod(`, or `getDeclaredField(` anywhere in the test. |
| TR-003 (missing ArgumentCaptor) | `verify(mock).method(any())` or `any(X.class)`/`eq(...)` used on a call whose argument is a multi-field object, where the strategy entry names an `argument_captor_opportunities` item for that exact call. |
| TR-004 (missed parameterization) | Two or more `@Test` methods differing only in literal input values and expected output, with no `@ParameterizedTest`/`@ValueSource`/`@CsvSource`/`@MethodSource`, where the strategy entry names a `parameterization_opportunities` item covering them. |
| TR-005 (implementation-detail assertions) | Assertions on private field state via reflection, or `verify()` checking an internal call sequence/order that is not part of the class's public contract, instead of asserting the observable return value or externally-visible side effect. |
| TR-006 (unnecessary mocking of simple objects) | `@Mock`/`mock(...)` applied to a class with no injected dependencies of its own and no meaningful behavior to stub (plain DTO, value object, or an internally-`new`'d stateless utility never constructor-injected). |
| TR-007 (inappropriate @SpringBootTest) | `@SpringBootTest` (or `@WebMvcTest` loading more context than needed) present on a test class whose strategy entry's `architecture_constraints` calls for a pure unit test. |

When the strategy or test invents a rule ID outside TR-001..TR-007 (or a project has since renumbered), treat it as unresolved unless it is confirmed present and enabled in this run's KB read.

## Reflection Pass Checklist

Before any draft finding is allowed into the final report, re-verify it against source:

1. **KB findings** — Re-confirm the cited rule ID appears in this run's `enabled: true` set (from the KB file or the orchestrator-supplied subset). Discard if the rule is disabled, deleted, or was misquoted.
2. **"Missing test" findings** — Re-search the full test file for a method that satisfies the strategy item under a different name, ordering, or grouping (e.g. one parameterized test covering what looks like two missing cases). Discard if found.
3. **"Drift" findings** — Re-read the exact line(s) of the production class cited as evidence. Discard if the class actually still matches what the test asserts.
4. **"Untraceable test" findings** — Re-check the strategy entry's full item list (including `argument_captor_opportunities` and `parameterization_opportunities`, not just `public_behaviors`) before calling a test untraceable.
5. **Exclusion findings** — Re-check the exact wording of the matching `excluded_tests` entry; a partially-related exclusion is not the same violation.
6. **Execution-failure findings** — These are ground truth from a real test run, not re-derivable as false positives. The reflection pass's only job for this category is to enrich the finding with production-source context (a likely cause, cited by line) — never to discard or downgrade it, and never to decide fixability.

Log every re-check outcome (`confirmed` or `discarded`, with reason) in the report's `reflection_log`, even for findings that survive.

## Review Report Schema

Write exactly `.ai-test-engineer/review/current-review.yaml`, overwriting any prior run:

```yaml
version: "1.0"
generated_by: nw-unit-test-reviewer
generated_at: <ISO-8601 timestamp>
class: <fully-qualified class name under review>
test_file: <path under src/test/java/**>
production_file: <path under src/main/java/** or tech-stack.yaml source root>
strategy_ref: .ai-test-engineer/test-strategy.yaml#classes[<index or class name>]
kb_ref: .ai-test-engineer/test-review-kb.yaml
enabled_rules: [TR-001, TR-003, ...]   # exactly the rule IDs treated as enabled this run
verdict: approved | revisions_needed
summary: "<one-paragraph human-readable rollup>"
findings:
  - id: F-001
    category: traceability | coverage_gap | behavior_drift | kb_violation | exclusion_violation | quality_signal | execution_failure
    severity: high | medium | low
    kb_rule: TR-00X            # present only for category: kb_violation
    test_method: <method name> # when the finding is scoped to one test method
    description: "<what is wrong>"
    evidence: "<cited line(s)/file(s) that ground this finding>"
    recommendation: "<what should change, and which agent should apply it>"
reflection_log:
  - draft_finding: "<the original draft claim>"
    outcome: confirmed | discarded
    reason: "<why it survived or was discarded>"
kb_gap_assessment:
  gap_found: true | false
  rationale: "<why a new/changed rule was or was not warranted>"
kb_edit:
  changed: true | false
  action: added | updated | deleted | null
  rule_id: <TR-00X or null>
  before: <prior entry or null>
  after: <new entry or null>
  reason: "<evidence-based justification, citing the finding(s) that drove it>"
```

`verdict: approved` requires zero `high` severity findings and zero unresolved `medium` findings; any surviving `high` finding, or a pattern of unresolved `medium` findings, sets `revisions_needed`. Any `execution_failure` finding is always `high` and never discardable (see the Ground-Truth Precedence Rule above), so its mere presence is sufficient on its own to set `revisions_needed` regardless of every other finding's state.

## KB-Edit Governance Rule

The KB file (`.ai-test-engineer/test-review-kb.yaml`) is the shared rule set every strategist and generator run depends on. Default to **no edit**. Only edit when all of the following hold:

1. **Evidence-driven** — The gap, redundancy, or inaccuracy is grounded in a finding that survived the reflection pass this run (or across recent runs cited in the report), not a hypothetical or one-off style preference.
2. **Rare** — A single ambiguous or borderline case does not clear the bar; prefer recording it as a `quality_signal` finding and revisiting on repetition.
3. **Scoped to one entry** — Add exactly one new rule, update exactly one existing rule's description/severity/enabled state, or delete exactly one now-redundant/incorrect rule per run. Do not batch multiple KB changes into one run.
4. **Always logged** — Every KB edit is recorded in the same run's `kb_edit` section with the before/after state and the reason, so the change is auditable from the report alone without diffing the KB file.
5. **Additive-first** — Prefer adding a new rule (next available `TR-0xx` ID) over deleting an existing one; delete only when a rule is demonstrably wrong or fully superseded, not merely rare in practice.
