---
name: nw-test-engineer
description: State schema, loop-bound decision rule, final-report schema, and domain-blindness boundary for the nw-test-engineer orchestrator — the sequencing knowledge behind the local unit-test factory pipeline.
user-invocable: false
disable-model-invocation: true
---

# nw-test-engineer: Orchestration Knowledge

This skill holds the sequencing/bookkeeping knowledge for orchestrating six leaf agents over `.ai-test-engineer/`. It
contains zero Mockito/JUnit/KB-rule content by design — that knowledge belongs to the leaf agents themselves.

## 1. Leaf Agent Invocation Contract

| Stage        | Leaf Agent                 | Reads                                                                                                             | Writes                                                                                                                        |
|--------------|----------------------------|-------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------|
| ANALYZE      | `nw-project-analyzer`      | repo manifests                                                                                                    | `.nwave/tech-stack.yaml` — **skipped entirely (no Task call) when this file already exists**, see Section 1a                  |
| STRATEGIZE   | `nw-unit-test-strategist`  | `.nwave/tech-stack.yaml`, `.ai-test-engineer/test-review-kb.yaml`, production source                              | `.ai-test-engineer/test-strategy.yaml` — overwritten every run, by design (Section 1b)                                        |
| GENERATE     | `nw-unit-test-generator`   | strategy entry, KB, production/existing test source                                                               | `src/test/java/**/*Test.java`                                                                                                 |
| BUILD VERIFY | `nw-test-build-verifier`   | real build/test run                                                                                               | `.ai-test-engineer/verify/build-verification.yaml` (`build.status`, `tests.status`, `generated_tests.status`)                 |
| REVIEW       | `nw-unit-test-reviewer`    | generated tests, production, strategy, KB, **this pass's `build-verification.yaml`**                              | a **new, non-overwriting** file under `.ai-test-engineer/review/` (`verdict` field) — filename is never fixed, see Section 1c |
| FIX          | `nw-unit-test-issue-fixer` | the review file at the exact path the orchestrator captured from REVIEW's completion response, affected files, KB | edits flagged test file(s), `.ai-test-engineer/review/fix-report.yaml`                                                        |

BUILD VERIFY is listed first because it now runs at the start of every loop pass, before that pass's REVIEW call — never
as a single trailing step after the loop. The orchestrator invokes each leaf via `Task` by name, passing the target
class (es) and any relevant file paths as context. It never performs a leaf's own job, and never reads beyond the
specific status/verdict field it needs to decide what runs next.

### 1a. ANALYZE Skip Rule

Before invoking `nw-project-analyzer`, attempt a plain Read of `.nwave/tech-stack.yaml`. If it exists, skip the Task
call entirely for this run — the file is treated as current, with no staleness check (the same rule the
strategist/generator already apply when they consume it). If it does not exist, invoke `nw-project-analyzer` as normal.
This is a structural existence check, not a domain judgment, so it stays consistent with Core Principle 1 (domain-blind
by design).

### 1b. STRATEGIZE Overwrite Rule

Unlike REVIEW's report (1c below), `.ai-test-engineer/test-strategy.yaml` is a current-state plan, not a history —
`nw-unit-test-strategist` overwrites it every run by design, and the orchestrator never works around or objects to that.

### 1c. REVIEW's Non-Fixed Report Path

`nw-unit-test-reviewer` never writes to a fixed filename — each run's review report is named uniquely (see that agent's
own spec for the exact scheme) so that no run ever overwrites a prior one's history. This means the orchestrator cannot
assume any literal path like `.../current-review.yaml`. After every REVIEW Task call, the orchestrator must read the
exact filename out of that call's completion response and use it for (a) the `verdict` Read this same pass, and (b) the
file path handed to `nw-unit-test-issue-fixer` if FIX runs this pass. This captured path is also what gets recorded in
this pass's `review_history` entry in the FINAL REPORT (Section 5).

## 2. state.yaml Schema

```yaml
phase: initialization | analyze | strategize | generate | review | fix | build_verify | final_report
iteration: 0            # count of FIX applications so far this run, 0-indexed
max_iterations: 3        # loop bound; see Section 3 for resolution order
status: not_started | in_progress | completed | failed
target_classes: []       # optional, echoes the class(es) named for this run
```

Defaults on first run (file absent): `phase: initialization, iteration: 0, max_iterations: 3, status: not_started`.

## 3. Phase Transition Table

| Step                                        | phase value      | status sequence                                                                   | iteration change                    |
|---------------------------------------------|------------------|-----------------------------------------------------------------------------------|-------------------------------------|
| Init                                        | `initialization` | `not_started` -> (unchanged until ANALYZE starts)                                 | none                                |
| ANALYZE                                     | `analyze`        | `in_progress` -> `completed`                                                      | none                                |
| STRATEGIZE                                  | `strategize`     | `in_progress` -> `completed`                                                      | none                                |
| GENERATE                                    | `generate`       | `in_progress` -> `completed`                                                      | none                                |
| BUILD VERIFY (each pass, before its review) | `build_verify`   | `in_progress` -> `completed`                                                      | none                                |
| REVIEW (each pass)                          | `review`         | `in_progress` -> `completed`                                                      | none                                |
| FIX (each pass)                             | `fix`            | `in_progress` -> `completed`                                                      | `iteration += 1` after the fix call |
| FINAL REPORT                                | `final_report`   | `in_progress` -> `completed` (or `failed` if a leaf could not produce its output) | none                                |

Persist the file after every row in this table, not only at the end of the run — a resumed/re-invoked run should find an
accurate snapshot even though full resume logic is out of scope for v1.

`max_iterations` resolution order: (1) an orchestrator-config override passed in by the invoking context for this run,
(2) the value already present in `state.yaml`, (3) default `3` when neither is available.

## 4. Loop-Bound Decision Rule (BUILD VERIFY / REVIEW / FIX)

Each loop pass starts with a fresh BUILD VERIFY call, not a REVIEW call — REVIEW's own contract (see the leaf's own
spec) requires a current `build-verification.yaml` to cross-reference, and is guaranteed to never return
`verdict: approved` while that file shows a real test failure for the class under review. Because of that guarantee, the
orchestrator's own break logic still needs only the `verdict` field — it never itself inspects `build.status`/
`tests.status` to decide whether to loop; that stays true to Core Principle 1 (domain-blind by design). Those fields are
read later only for the FINAL REPORT synthesis, not for loop control.

Each pass:

0. Call `nw-test-build-verifier` (BUILD VERIFY) to produce a fresh `.ai-test-engineer/verify/build-verification.yaml`
   reflecting the test file (s) as they currently stand.
1. Call `nw-unit-test-reviewer` (REVIEW), which reads that same `build-verification.yaml` as one of its own inputs.

Then, reading only the `verdict` field from `current-review.yaml`:

1. `verdict == approved` -> break the loop. Do not call FIX. This pass's `build-verification.yaml` is the one FINAL
   REPORT uses.
2. `verdict == revisions_needed` AND `iteration < max_iterations` -> call FIX, then `iteration += 1`, persist, loop back
   to step 0 (a fresh BUILD VERIFY, since FIX may have changed the test file).
3. `verdict == revisions_needed` AND `iteration >= max_iterations` -> break the loop (exhausted). Do not call FIX again.
   This pass's `build-verification.yaml` is the one FINAL REPORT uses.

This rule is evaluated fresh every pass against the current `max_iterations` value — it is never a hardcoded count of
calls. With `max_iterations: 3` and no early approval, this rule produces exactly BUILD VERIFY+REVIEW, FIX, BUILD
VERIFY+REVIEW, FIX, BUILD VERIFY+REVIEW (3 build-verify+review pairs, 2 fixes) before the break — a worked consequence
of the rule, not a separately hardcoded number. There is no longer a separate, trailing "BUILD VERIFY" step after the
loop — the last pass's result already is that final ground-truth read.

## 5. Final Report Schema (`.ai-test-engineer/reports/final-report.yaml`)

Fixed path, overwritten every run — like `test-strategy.yaml` (Section 1b) and unlike REVIEW's report (Section 1c), this
is a current-state summary, not a history, so no timestamping or sequencing applies here. Create the `reports/`
directory if it does not yet exist.

```yaml
run:
  target_classes: []               # class(es) processed this run
  max_iterations: 3
  iterations_used: 0                # final iteration count reached
review_history:
  - iteration: 0
    verdict: approved | revisions_needed
    review_file: "<exact path captured from that pass's nw-unit-test-reviewer completion response>"
fix_history:
  - iteration: 0
    summary: "<echoed one-line summary from that pass's fix-report.yaml>"
build_verify:
  build_status: passed | failed
  tests_status: passed | failed
  generated_tests_status: valid | invalid
outcome: ready | needs_manual_attention
outcome_reason: "<one line stating which condition drove the outcome>"
```

**Outcome rule**: `ready` iff the loop exited via an approved verdict AND `build_verify.build_status == passed` AND
`build_verify.tests_status == passed`. Every other combination — loop exhausted `max_iterations` while still
`revisions_needed`, or a build/test failure even after an approved review — is `needs_manual_attention`, with
`outcome_reason` naming the specific condition that failed.

This schema exists so a human or a downstream workflow can answer "is this class's test suite done" from one small file,
without re-deriving the answer from six other artifacts.

## 6. Domain-Blindness Boundary

The orchestrator never does any of the following — each belongs to a leaf agent:

- Read any file under `src/main/java/**` or `src/test/java/**`.
- Read `.ai-test-engineer/test-review-kb.yaml` (KB rule content is the strategist/reviewer/fixer's domain).
- Read the `findings` body of REVIEW's report file, the plan body of `test-strategy.yaml`, or the `failures[]` body of
  `build-verification.yaml` — only the specific top-level field needed: `verdict` for loop control, and `build.status`/
  `tests.status`/`generated_tests.status` for the FINAL REPORT synthesis only (never to decide whether to loop —
  REVIEW's own contract already guarantees `verdict` reflects ground truth).
- Write or edit a test file, a production file, `test-review-kb.yaml`, or any leaf's own report file (`tech-stack.yaml`,
  `test-strategy.yaml`, REVIEW's own report file, `fix-report.yaml`, `build-verification.yaml`).
- Judge test quality, Mockito style, or KB compliance itself — it only routes to the agent whose job that is.

Its only writes, ever, are `.ai-test-engineer/state.yaml` and `.ai-test-engineer/reports/final-report.yaml`.
