---
name: nw-unit-test-issue-fixer
description: Fix-pattern-per-finding-category table, concrete detection heuristics for the production-read-only rule and the never-weaken-an-assertion rule, and the fix-report schema for repairing JUnit test files flagged by a caller-supplied nw-unit-test-reviewer report file.
user-invocable: false
disable-model-invocation: true
---

# Unit Test Issue Fixer — Domain Knowledge

## Fix-Pattern-per-Finding-Category Table

Map each finding's `category` (from the reviewer's taxonomy) to its typical fix pattern. Every pattern below is category
(a) — a genuine test defect — unless the "Escalation trigger" column's condition holds, in which case it becomes
category (b).

| Category              | Typical Fix Pattern (category a)                                                                                                                                                                                                                           | Escalation Trigger (category b)                                                                                                                                                                                                                  |
|-----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `traceability`        | Delete or rename the untraceable filler test; or add the missing link comment if it actually does trace under a different name (verify before touching).                                                                                                   | Never escalates — traceability is a test-authoring defect only, not a production question.                                                                                                                                                       |
| `coverage_gap`        | Add exactly the one test method the finding names, scoped to the single named strategy item, following the project's existing BDD naming/fixture-helper convention.                                                                                        | Never escalates on its own — but if writing the missing test reveals the production code cannot produce the strategy's intended behavior, stop and treat it as a fresh `behavior_drift`-style escalation instead of forcing a passing assertion. |
| `behavior_drift`      | Update the test's assertion to match the production class's current behavior **only when** that current behavior still satisfies the strategy's stated intended behavior (e.g. a renamed field, a reordered call that is not part of the public contract). | Escalate when the production class's current behavior diverges from the strategy's stated intended behavior (a spec-level mismatch, not a cosmetic one) — see Hard Rule 2 checklist below.                                                       |
| `kb_violation`        | Apply the cited rule's canonical shape from `nw-unit-test-generator`'s KB Rule -> Code Shape table (e.g. add the named `ArgumentCaptor`, swap `spy()` for `mock()`, remove `@SpringBootTest`, collapse into `@ParameterizedTest`).                         | Never escalates — a KB-rule violation is always a test-mechanics defect, never a production-behavior question.                                                                                                                                   |
| `exclusion_violation` | Remove a test that covers something `excluded_tests` explicitly excludes; or, if the exclusion itself was wrong, do not add the missing coverage yourself — report as `skipped_out_of_scope` and note the strategy needs revisiting.                       | Escalates to `skipped_out_of_scope` (strategy-level issue, not this agent's authority) rather than `escalated_production_defect`.                                                                                                                |
| `quality_signal`      | Fix the concrete quality defect named (seed a fixed `Clock`, add the missing assertion on a stubbed path, replace a can't-fail assertion).                                                                                                                 | Escalate if the "fix" would require changing what counts as correct output rather than tightening how the test checks it.                                                                                                                        |

## Hard Rule 1 — Production Read-Only: Detection Heuristics

Before proposing or applying any edit, confirm the target path is under the test source root (e.g. `src/test/java/**`),
never under the production source root (e.g. `src/main/java/**`, or the source root recorded in
`.nwave/tech-stack.yaml`).

1. A draft fix that names a production file as its edit target is invalid by construction — reclassify it as
   `escalated_production_defect` regardless of how small the change looks (a one-line typo fix is still a production
   edit).
2. A draft fix is never valid if it would require changing the class under test's method signature, field, or return
   type to make a test compile or pass.
3. Reading a production file for grounding is always allowed and expected; editing, formatting, or "just adding a null
   check" to one is not, under any finding category.

## Hard Rule 2 — Never Weaken an Assertion: Detection Heuristics

This is the central judgment call. For every finding whose fix touches an assertion's expected value, exception type,
matcher, or comparison target, run this WHY-check before drafting the fix:

1. **Locate the strategy's intended behavior** for the exact item the finding names (from `test-strategy.yaml`'s
   `public_behaviors`, `branches`, `exceptional_cases`, or `boundary_conditions` — not the test's own prior assertion,
   which may itself be stale).
2. **Re-read the production class's current, actual behavior** at the exact call/branch the finding cites — fresh this
   run, not the strategy's summary of it and not the prior test's assumption.
3. **Compare the two.** Three outcomes:
    - Production behavior matches the strategy's intended behavior, but the test's assertion is wrong for a mechanical
      reason (wrong mock stub, wrong captor target, stale value left over from a refactor, a missed KB-rule shape) ->
      **category (a)**, fix the test.
    - Production behavior matches the strategy's intended behavior, and the test's assertion already matches too, but
      the finding was a false read -> **`skipped_no_change_needed`**, no edit.
    - Production behavior itself diverges from the strategy's stated intended behavior -> **category (b)**, the test
      correctly caught a real defect. Do not rewrite, loosen, delete, or retarget the assertion to match what the
      production code currently outputs. Leave the test exactly as it is (still failing/flagging) and escalate.
4. **Concrete red flags that a draft fix has silently crossed into category (b)** — reject/downgrade the draft fix if
   any hold:
    - The fix changes an assertion's expected *value* to whatever the production code currently returns/throws, with no
      corresponding change to the strategy's stated intended behavior justifying it.
    - The fix changes an exception type, HTTP status, or return type in the assertion to match production's current
      output where the strategy names a different intended type/status.
    - The fix removes or comments out an assertion rather than correcting the mock/captor/setup around it.
    - The reasoning for the fix reduces to "this makes the test pass" without a citation to a mechanical test defect
      (wrong stub, wrong captor, stale value, missed KB shape).
5. When in doubt between (a) and (b), default to (b) — escalate. A missed fix costs a follow-up run; a silently weakened
   assertion costs the safety net the review pipeline exists to protect.

## Fix-Report Schema

Write exactly `.ai-test-engineer/review/fix-report.yaml`, overwriting any prior run:

```yaml
version: "1.0"
generated_by: nw-unit-test-issue-fixer
generated_at: <ISO-8601 timestamp>
review_ref: <exact path of the review-report file this run acted on, as supplied by the caller or discovered via fallback Glob>
review_verdict: approved | revisions_needed
class: <fully-qualified class name, from the input review>
test_file: <path under src/test/java/**, from the input review>
production_file: <path under src/main/java/**, read-only, from the input review>
summary: "<one-paragraph human-readable rollup, mirroring the reviewer's evidence-citing style>"
outcomes:
  - finding_id: F-001                # matches the id from the input review-report file; or "none" when review had zero findings
    outcome: fixed | escalated_production_defect | skipped_no_change_needed | skipped_out_of_scope
    category: kb_violation | traceability | coverage_gap | behavior_drift | exclusion_violation | quality_signal
    test_method: <method name>        # when scoped to one method
    fix_applied: "<what was edited, or null when outcome is not fixed>"
    reasoning: "<why this outcome, citing the strategy's intended behavior and the freshly re-read production line(s) for any behavior_drift-related finding>"
    escalation_note: "<only present when outcome is escalated_production_defect — routes the behavioral discrepancy to humans/orchestrator, states the strategy's intended behavior vs. the production class's actual current behavior, and explicitly states no production-code change was made by this agent>"
reflection_log:
  - finding_id: F-00X
    draft_fix: "<what the Draft Fix pass initially proposed>"
    reflect_outcome: confirmed | downgraded
    reason: "<why the draft fix survived reflection, or why it was downgraded to escalated_production_defect/skipped>"
```

`outcomes` always has exactly one entry per finding in the input review, in the same order. When the input review is
`approved` with an empty `findings` list, `outcomes` has exactly one entry with `finding_id: none`,
`outcome: skipped_no_change_needed`, and a reasoning string stating the review was approved with no findings.
