---
name: nw-test-build-verifier
description: Maven/Gradle command and report-parsing tables, phase-classification signatures, short-circuit decision tree, generated-tests validity rule, and report schema for real build/test verification.
user-invocable: false
disable-model-invocation: true
---

# Test Build Verifier — Domain Knowledge

## 1. Build Tool Command Table

| Build Tool | Wrapper Check                                   | Wrapper Command  | Fallback Command | Fallback Trigger                  |
|------------|-------------------------------------------------|------------------|------------------|-----------------------------------|
| Maven      | `./mvnw` present and executable at repo root    | `./mvnw test`    | `mvn test`       | wrapper missing or not executable |
| Gradle     | `./gradlew` present and executable at repo root | `./gradlew test` | `gradle test`    | wrapper missing or not executable |

Always attempt the wrapper first. Record `wrapper_fallback: true` and the exact fallback reason whenever the system tool
is used instead.

## 2. Phase-Classification Signatures (from combined command output)

Both Maven's `test` goal and Gradle's `test` task run their compile -> test-compile -> test lifecycle in one invocation.
Classify the single run's combined output/exit code against these signatures rather than issuing three separate
commands.

Maven:

| Phase              | Signature in Output                                                                                                                      | Maps To                                                                          |
|--------------------|------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------|
| Production compile | `Failed to execute goal ... maven-compiler-plugin:...:compile` or a `COMPILATION ERROR` block appearing before any `testCompile` mention | `build.status: failed`, `build.error`                                            |
| Test compile       | `Failed to execute goal ... maven-compiler-plugin:...:testCompile`                                                                       | `build.status: passed`, `tests.status: failed`, `tests.error`                    |
| Test execution     | `Failed to execute goal ... maven-surefire-plugin:...:test` or `Tests run: N, Failures: F, Errors: E` with `F+E > 0`                     | `build.status: passed`, `tests.status: failed`, `failures` from surefire reports |
| Clean pass         | `BUILD SUCCESS`                                                                                                                          | `build.status: passed`, `tests.status: passed`                                   |

Gradle:

| Phase              | Signature in Output                                               | Maps To                                                                   |
|--------------------|-------------------------------------------------------------------|---------------------------------------------------------------------------|
| Production compile | `Execution failed for task ':compileJava'`                        | `build.status: failed`, `build.error`                                     |
| Test compile       | `Execution failed for task ':compileTestJava'`                    | `build.status: passed`, `tests.status: failed`, `tests.error`             |
| Test execution     | `Execution failed for task ':test'` or `There were failing tests` | `build.status: passed`, `tests.status: failed`, `failures` from JUnit XML |
| Clean pass         | `BUILD SUCCESSFUL`                                                | `build.status: passed`, `tests.status: passed`                            |

## 3. Structured Report Sources

| Build Tool | Report Location                                                    | What To Extract                                                                                   |
|------------|--------------------------------------------------------------------|---------------------------------------------------------------------------------------------------|
| Maven      | `target/surefire-reports/*.txt` (summary) and `*.xml` (structured) | Per-class `Tests run`/`Failures`/`Errors`; `<failure>`/`<error>` message + trace per `<testcase>` |
| Gradle     | `build/test-results/test/*.xml` (JUnit XML)                        | `<testsuite tests= failures= errors=>` and per-`<testcase>` `<failure message=...>`               |

Sum counts across all report files for `tests.total`/`tests.failed`. Build `failures` from every `<testcase>` carrying a
`<failure>`/`<error>` child, named `<ClassName>.<methodName>`, with the trimmed failure message as `reason`.

## 4. Short-Circuit Decision Tree

```
Run build tool's `test` command once, capture exit code + combined output
|
├─ Exit code 0 (BUILD SUCCESS/SUCCESSFUL)
│    -> build.status: passed, tests.status: passed
│    -> parse structured reports for total/failed/failures
│    -> classify generated_tests (section 5)
│
├─ Exit code != 0, signature matches production-compile failure
│    -> build.status: failed, build.error: <captured compiler message>
│    -> tests.status: failed (never ran); total/failed omitted
│    -> failures: []  (nothing test-level to report — the compile error is the finding)
│    -> generated_tests.status: invalid, reason: "production did not compile; nothing could run"
│    -> SHORT-CIRCUIT: skip structured-report parsing entirely
│
├─ Exit code != 0, signature matches test-compile failure
│    -> build.status: passed (production compiled fine)
│    -> tests.status: failed, tests.error: <captured test-compile message>
│    -> failures: []  (no test report exists yet)
│    -> generated_tests.status: invalid IF the failing file is among the named generated/fixed files, else valid pending re-check next run
│    -> SHORT-CIRCUIT: skip structured-report parsing (no report was produced)
│
└─ Exit code != 0, signature matches test-execution failure
     -> build.status: passed, tests.status: failed
     -> parse structured reports for total/failed/failures (they exist — tests ran)
     -> classify generated_tests (section 5)
```

## 5. Generated-Tests Validity Classification

Given the invoking context's named generated/fixed test file (s) (e.g. `UserServiceImplTest.java`):

- `invalid` if the file appears in a test-compile error message, OR any failing test in the structured report belongs to
  a class defined in that file.
- `valid` if the build passed cleanly through test-compile AND every test belonging to that file's class (es) appears in
  the structured report with zero failures.
- `valid` with a caveat when the file's class produced zero test executions at all (e.g. an empty test class) — state
  this in `reason` rather than silently marking valid.
- Never infer validity from the whole-suite total alone — a green whole-suite does not confirm the named file
  specifically ran; always cross-reference by class/method name against the structured report.

## 6. Report Schema

Write exactly `.ai-test-engineer/verify/build-verification.yaml`, overwriting any prior run:

```yaml
version: "1.0"
generated_by: nw-test-build-verifier
generated_at: <ISO-8601 timestamp>
build_tool: maven | gradle
command_used: "./mvnw test" | "mvn test" | "./gradlew test" | "gradle test"
wrapper_fallback: true | false
wrapper_fallback_reason: "<why, only present when true>"
build:
  status: passed | failed
  error: "<compiler error message, only present when status: failed>"
tests:
  status: passed | failed
  total: <int>              # omitted when tests never ran
  failed: <int>             # omitted when tests never ran
  error: "<test-compile error message, only present on a test-compile failure>"
generated_tests:
  status: valid | invalid
  files: [<generated/fixed test file(s) named in the invoking context>]
  reason: "<why invalid, or the zero-execution caveat>"
failures:
  - test: "<ClassName.methodName>"
    reason: "<trimmed failure/error message from the structured report>"
```
