---
name: nw-unit-test-strategist
description: KB rule application map, mocking-strategy decision table, exclusion heuristics, and test-strategy.yaml output schema for Java/Spring unit-test planning
user-invocable: false
disable-model-invocation: true
---

# Unit Test Strategist Planning Catalog

Reference tables for deciding WHAT to test and HOW in a Java/Spring codebase, before any test code exists. Every
decision that a KB rule drove must cite that rule's ID; every decision with no rule behind it cites none.

## 1. KB Rule Application Map

Only rules with `enabled: true` in `.ai-test-engineer/test-review-kb.yaml` apply. A disabled or absent rule ID must
never appear in `kb_rules_applied`.

| Rule ID | Description                                              | Plan Field It Drives                 | Trigger                                                                                                                                                                                                                                        |
|---------|----------------------------------------------------------|--------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| TR-001  | Avoid Mockito spy unless partial mocking is required     | `dependencies[].mocking_strategy`    | Collaborator only needs some real behavior + some stubbed — default to full mock first, spy only if a draft shows partial mocking is unavoidable                                                                                               |
| TR-002  | Avoid reflection for private methods                     | `public_behaviors`, `excluded_tests` | A private helper's logic is only reachable/verifiable through a public method — plan the test at the public entry point, never via reflection                                                                                                  |
| TR-003  | Prefer ArgumentCaptor for complex dependency arguments   | `argument_captor_opportunities`      | A mocked collaborator call takes a non-trivial object (DTO, builder result, domain entity) as argument and the plan needs to assert on that argument's contents — plan an ArgumentCaptor assertion instead of a loose `any()`/equality matcher |
| TR-004  | Prefer parameterized tests for repeated input variations | `parameterization_opportunities`     | Same method, multiple input/output pairs differing only by value (e.g. several null/blank/invalid inputs hitting the same branch)                                                                                                              |
| TR-005  | Test behavior, not implementation details                | `public_behaviors`, `excluded_tests` | Draft plan drifts toward asserting internal call order/private state instead of observable outcome — reframe around the public contract                                                                                                        |
| TR-006  | Avoid unnecessary mocking of simple objects              | `dependencies[].mocking_strategy`    | Collaborator is a value object, DTO, or stateless utility instantiated internally (not injected) — mark `mocking_strategy: real`, not `mock`                                                                                                   |
| TR-007  | Avoid @SpringBootTest for pure unit tests                | `architecture_constraints`           | Class has no Spring-context-dependent wiring beyond constructor injection — plan a plain unit test (mock constructor args), reserve `@SpringBootTest`/`@WebMvcTest` for slice/integration-level plans only                                     |

## 2. Mocking Strategy Decision Table

Apply per dependency found in the class's constructor/fields, in this order:

| Collaborator Shape                                                                                                                              | Strategy                                                          | Rationale                                                                                                            | Related Rules  |
|-------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------|----------------|
| External client/template crossing a process or network boundary (`StringRedisTemplate`, `RestTemplate`, a repository interface, an HTTP client) | `mock`                                                            | Boundary is the thing under test's contract with the outside world — verify interaction, don't hit the real resource | TR-001, TR-003 |
| Stateless utility instantiated internally, not constructor-injected (`new ObjectMapper()`, `new SimpleDateFormat()`)                            | `real`                                                            | Not a collaborator the class depends on for behavior variation — mocking it adds test brittleness with no signal     | TR-006         |
| Simple value object / DTO passed as a method argument (not a field)                                                                             | `real` (construct a real instance in the test)                    | Mocking a data-holder verifies nothing behavior only Java itself guarantees                                          | TR-006         |
| Another service/component this class delegates to for business logic (`UserService` from a controller)                                          | `mock`                                                            | Isolate the unit under test from downstream business logic already covered by that dependency's own plan             | TR-001         |
| Collaborator needing some real methods and some stubbed (rare)                                                                                  | `spy` — only after `mock` is shown insufficient in the draft pass | Spies couple tests to internal call sequencing                                                                       | TR-001         |

## 3. Serialization Testability Check

Run this check for every candidate class that serializes or deserializes an object through a dependency (`ObjectMapper`,
a mapper/codec library, etc.) before drafting any behavior/boundary item that depends on a round-trip or field-level
property of that object.

1. Identify every object type passed to a (de)serialization call (e.g. the argument to `writeValueAsString`, the target
   type of `readValue`).
2. Read that object's own class definition — not just the service class already grounded in step 3 of the Workflow — for
   field-level annotations affecting (de)serialization: `@JsonIgnore`, `@JsonProperty`, a custom `@JsonSerialize`/
   `@JsonDeserialize`, a `transient` field honored by the codec in use, etc.
3. For every naively-expected property a draft behavior/boundary item would assert (e.g. "the field survives a round
   trip"), check whether an identified annotation deterministically breaks it.
4. If it does, and the class cannot be modified (production code is out of this pipeline's authority), do not plan that
   specific item as an assertable behavior/boundary/exceptional-case. Record it in `unresolved` with a `note` describing
   the property, the exact annotation/mechanism that breaks it, and that the correctness of either outcome is a human
   decision — not something this agent or a generated test may resolve unilaterally.
5. This check excludes only the specific unachievable property, not the whole class or method — every other real,
   achievable behavior of that class/method is still planned normally.

This is a targeted extension of Core Principle 2 (ground every claim in real source): a service class's own source is
not sufficient grounding when its behavior depends on how another class's fields are (de)serialized.

## 4. ArgumentCaptor Opportunity Heuristics

Evaluate every mocked dependency call, systematically, not just when one happens to stand out — this check runs for
every `mocking_strategy: mock` (or `spy`) dependency, on every candidate class.

| Condition                                                                                                                                                         | Verdict                                 | JUnit 5 / Mockito Pattern                                                                                                                                                                                                                                                                                                         | Related Rule                                      |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------|
| Argument is a DTO, domain entity, builder result, or other multi-field object, and the plan needs to assert on its contents (not just that some value was passed) | Captor opportunity — record it          | `@ExtendWith(MockitoExtension.class)` class + `@Captor ArgumentCaptor<User> userCaptor;` field (or a local `ArgumentCaptor.forClass(User.class)` if the extension isn't already in the plan); `verify(userService).createUser(userCaptor.capture());` then assert on `userCaptor.getValue()` (e.g. via AssertJ `assertThat(...)`) | TR-003                                            |
| Argument is a primitive, `String`, enum, or other single-value type, and reference/value equality is all the plan needs                                           | Not a captor opportunity                | Plan a plain `verify(mock).method(eq(value))` or `verify(mock).method("literal")` instead                                                                                                                                                                                                                                         | TR-003 (rule confirms captor is unnecessary here) |
| Multiple invocations of the same mocked method with different argument values, where each call's argument needs its own assertion                                 | Captor opportunity — note multi-capture | `verify(mock, times(n)).method(captor.capture());` then assert against `captor.getAllValues()`                                                                                                                                                                                                                                    | TR-003                                            |
| Dependency's `mocking_strategy` is `real` (TR-006)                                                                                                                | Not applicable                          | No mock exists to verify against — skip the check for this dependency                                                                                                                                                                                                                                                             | —                                                 |

Record every match as a class-level `argument_captor_opportunities` entry naming the dependency, the method, and why a
captor beats a loose matcher. When no mocked dependency call qualifies, still run the check and leave the list empty
rather than omitting the check.

## 5. Exclusion Heuristics — What NOT to Plan a Test For

| Category                                                   | Example                                                                                                                               | Justification                                                                                                                                                | Related Rules                                                           |
|------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------|
| Lombok/framework-generated accessors                       | `@Data`/`@Getter`/`@Setter` fields on an entity/DTO with no custom logic                                                              | Behavior is guaranteed by the annotation processor, not hand-written                                                                                         | TR-005                                                                  |
| Framework-guaranteed wiring                                | `@SpringBootApplication` main class, `@Configuration` classes with only `@Bean` factory methods delegating to a framework constructor | Spring itself is already tested upstream; no custom branch to verify                                                                                         | TR-007                                                                  |
| Private helper logic already covered via its public caller | A `private` method inlined inside a public method already planned                                                                     | TR-002 forbids reaching it via reflection; its behavior is exercised through the public entry point already in the plan                                      | TR-002                                                                  |
| Trivial one-line delegation with zero branching            | A controller method that only calls one service method and returns its result, no validation/transformation                           | No behavior of this class's own to verify beyond "it calls X" — note as skip or fold into a thin integration/slice test elsewhere, not a dedicated unit test | TR-005                                                                  |
| Property broken by a (de)serialization annotation          | A field with `@JsonIgnore` (or similar) that a naive test would assert survives a round-trip through a mapper                         | The property is deterministically false given current, unmodifiable production code; asserting it either way is a human decision, not this agent's to make   | Serialization Testability Check (Section 3), not a specific TR-0xx rule |

Every exclusion still gets a `skip_reason` string. Cite a rule ID in `kb_rules_applied` only when a specific enabled
rule drove the exclusion; use a plain justification string when it's a general heuristic (e.g. Lombok accessors, or an
untestable-without-production-change property) not tied to any TR-0xx entry.

## 6. test-strategy.yaml Output Schema

```yaml
version: "1.0"
generated_by: nw-unit-test-strategist
generated_at: {ISO-8601 timestamp}
source_context:
  tech_stack: .nwave/tech-stack.yaml
  kb: .ai-test-engineer/test-review-kb.yaml
  enabled_rules: [TR-001, TR-002, TR-003, TR-004, TR-005, TR-006, TR-007]
classes:
  - class: com.example.pkg.UserServiceImpl
    file: src/main/java/com/example/pkg/UserServiceImpl.java
    requires_tests: true
    skip_reason: null
    public_behaviors:
      - "createUser persists a User under a generated id and returns the id"
    branches:
      - "createUser: user == null -> IllegalArgumentException"
    boundary_conditions:
      - "empty-string id"
    exceptional_cases:
      - "JsonProcessingException on serialize wrapped as RuntimeException"
    dependencies:
      - name: StringRedisTemplate
        role: collaborator
        mocking_strategy: mock
        rationale: "external Redis boundary"
      - name: ObjectMapper
        role: internal-utility
        mocking_strategy: real
        rationale: "stateless utility instantiated internally, not injected"
    parameterization_opportunities:
      - "null-argument validation across createUser/getUser shares one @ParameterizedTest"
    argument_captor_opportunities:
      - "createUser(User) on the internal save path — capture the User passed to the Redis write and assert its fields rather than relying on equals()"
    architecture_constraints:
      - "pure unit test; no Spring context required"
    excluded_tests: []
    kb_rules_applied: [TR-004, TR-006, TR-007]
  - class: com.example.pkg.User
    file: src/main/java/com/example/pkg/User.java
    requires_tests: false
    skip_reason: "Lombok-generated getters/setters only; no custom logic"
    kb_rules_applied: []
unresolved:
  - note: "getUser's returned User.id can never equal the lookup key because User.id is @JsonIgnore, stripped on both serialize and deserialize via ObjectMapper — may be intentional or a defect; requires a human decision before either outcome can be asserted"
    file: src/main/java/com/example/pkg/User.java
    reason: untestable_without_production_change
```

Field rules: `classes` is always an array, one entry per candidate class in scope, even skipped ones.
`requires_tests: false` entries still populate `class`, `file`, `skip_reason`, `kb_rules_applied` — all other fields may
be omitted. `argument_captor_opportunities` is evaluated for every `requires_tests: true` class with at least one mocked
dependency and is always present (as `[]` when the check found nothing) rather than omitted — the check itself is
mandatory even when its result is empty. `kb_rules_applied` lists only rule IDs that were `enabled: true` in the KB and
actually drove a decision on that entry; `[]` when none applied. `unresolved` records any class the agent could not
confidently plan (e.g. dependency type couldn't be resolved) with a `note` and `file`, and also records any single
behavior/boundary property excluded via the Serialization Testability Check (Section 3), tagged
`reason: untestable_without_production_change` — this is a per-property exclusion, distinct from a whole class's
`requires_tests: false` skip.
