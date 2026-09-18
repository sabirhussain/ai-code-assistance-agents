---
name: nw-unit-test-generator
description: Convention-sniffing heuristics, duplicate-detection rules, file-naming/output-location rules, and KB-rule-to-code-shape mappings for generating JUnit 5 test source from a unit-test-strategist plan
user-invocable: false
disable-model-invocation: true
---

# Unit Test Generator Code-Shape Catalog

Reference tables for turning a `test-strategy.yaml` entry into runnable JUnit 5 test source that matches the project's own conventions rather than generic defaults.

## 1. Convention-Sniffing Heuristics

| Signal | Detect By | Decision |
|---|---|---|
| Test class naming | Grep sibling `src/test/java/**/*.java` filenames | `*Test.java` if any sibling uses it, else `*Tests.java` if that is the only pattern present, else default `*Test.java` |
| Assertion library | Grep sibling test bodies for `org.assertj.core.api.Assertions.assertThat` vs `org.junit.jupiter.api.Assertions.assert*` | Use whichever is actually imported/used in >=1 sibling test; if neither appears anywhere in the module, default to plain JUnit 5 assertions even when AssertJ is on the classpath transitively — do not assume a style the project has not shown |
| Mockito setup style | Grep sibling tests for `@ExtendWith(MockitoExtension.class)` vs `@Mock` fields vs `Mockito.mock(...)` inline | Match the dominant style found; if none found, default to `@ExtendWith(MockitoExtension.class)` + `@Mock` fields (least boilerplate, standard idiom) |
| Package mirroring | Compare `src/main/java/<pkg>/<Class>.java` to `src/test/java/<pkg>/` | Test file always mirrors the production package path exactly |
| Fixture/base-class pattern | Glob `src/test/java/**/*Base*Test*.java`, `**/*Fixture*.java` | Extend/reuse an existing base/fixture class if the module has one and the class under test fits its scope; never invent a new shared base class for a single test file |
| Test method naming | Grep sibling `@Test`/`@ParameterizedTest` method names for an existing pattern | If siblings already use a consistent BDD-style pattern (e.g. `should...When...`, `given...when...then...`), match it exactly; otherwise default to `should<Outcome>When<Condition>` (e.g. `shouldReturnCreatedUserWhenCreateUserIsCalledWithValidUser`) rather than a bare method-under-test name like `testCreateUser` |

When zero sibling test files exist anywhere in the module beyond a smoke-test class (e.g. a `*ApplicationTests` context-load test), treat that as "no established convention" and apply the defaults column above.

## 2. Duplicate-Detection Rule

Before planning any test, read the existing test file (if any) for the class and extract its current `@Test`/`@ParameterizedTest` method names and the scenario each one exercises — from the method body, not the name alone, since a poorly-named existing test can still cover the scenario.

For each item in the strategy entry (behavior, branch, boundary, exceptional case, captor opportunity), mark it `already-covered` if an existing test method's body already exercises that exact input/outcome pair, otherwise `to-generate`.

If every item resolves to `already-covered`, make no file change and report a no-op listing which existing test method covers each item. Never regenerate or duplicate a scenario that already exists, even under a differently-named test method.

## 3. Single-Expectation Test Rule

Plan one test method per single observable expectation, not one test asserting several unrelated outcomes. When a strategy item implies multiple distinct checks for the same behavior — e.g. "returns the created user", "passes the same argument to the dependency", and "looks up by the returned id" are all facets of one `createUser` behavior — split them into separate, short, BDD-named test methods instead of one broad test that mixes concerns.

Each resulting test should: build its input via the fixture-builder helper (section 4), perform exactly one action on the class under test, and assert exactly one thing or one tightly-related group of assertions about a single outcome (e.g. status code + body together count as one outcome; a captured-argument assertion is a separate outcome from that). This keeps failures self-explanatory — a failing test's name alone states what broke — and keeps each test short enough to review at a glance. This rule operationalizes TR-005 (behavior, not implementation) at the test-structure level: one behavior facet, one test.

## 4. Fixture-Builder Helper Rule

When a planned test needs a non-trivial object (an entity/DTO with two or more fields, e.g. `User`) as input or expected output, generate a small private helper method (e.g. `private User buildUser() { ... }`) that returns a fresh, valid instance with representative field values, and call that helper from every test needing such an object instead of repeating field-by-field construction.

Create at most one helper per distinct object shape needed by the current class's plan. If the existing test file already has a same-shaped helper (detected via convention-sniffing — a `private` method prefixed `build`/`create`/`make` returning the needed type), reuse and extend it rather than adding a second, differently-named one. Skip the helper only for a genuinely trivial one-field object used by exactly one test, where inline construction is already as short as a helper call would be.

## 5. File Naming & Output Location Rule

Output path = `src/test/java/<same package path as production class>/<ClassName><suffix>.java`, where `<suffix>` is `Test` unless sibling convention-sniffing (section 1) established `Tests`. Source root substitutes the tech-stack.yaml build tool's convention when non-Maven (e.g. Gradle also uses `src/test/java`). When the file already exists, edit it — append new test methods inside the existing class — rather than overwriting; preserve every existing test method untouched.

## 6. KB Rule -> Code Shape Map

Applies to `enabled: true` rules only, matching IDs cited in the strategy entry's `kb_rules_applied` (or triggered fresh during generation, e.g. a captor opportunity the plan named but did not fully specify).

| Rule | Code Shape |
|---|---|
| TR-001 (avoid spy) | Use `mock(Dependency.class)` / `@Mock` for the dependency; never `spy()` unless the strategy entry explicitly names a partial-mocking need |
| TR-002 (no reflection) | Never use `Field.setAccessible`/reflection to reach a private method; test only via the public entry point the strategy names |
| TR-003 (ArgumentCaptor) | `@Captor ArgumentCaptor<User> userCaptor;` (or local `ArgumentCaptor.forClass(User.class)`) then `verify(dependency).method(userCaptor.capture());` followed by assertions against `userCaptor.getValue()` — use this whenever the strategy entry lists the call under `argument_captor_opportunities` |
| TR-004 (parameterized) | `@ParameterizedTest` + `@ValueSource`/`@NullAndEmptySource`/`@MethodSource` collapsing the strategy's listed input variations into one test method, one assertion shape |
| TR-005 (behavior not implementation) | Assert on the returned value, thrown exception type/message, or the argument captured at a boundary call — never assert on private field state or internal call ordering beyond what `verify(...)` on a named dependency already requires |
| TR-006 (no mocking simple objects) | Construct the real object (`new User()`, a real DTO) instead of mocking it; only boundary/business-logic dependencies get mocked. When the dependency is not constructor-injected at all (e.g. `private final ObjectMapper objectMapper = new ObjectMapper();`), the test needs no substitute for it whatsoever |
| TR-007 (no @SpringBootTest for units) | No `@SpringBootTest`/`@WebMvcTest`/`@ExtendWith(SpringExtension.class)` — instantiate the class under test directly with constructor args (mocks or reals per the dependency table) |

## 7. No-Op Report Format

```yaml
generated: false
class: com.example.pkg.UserController
existing_test_file: src/test/java/com/example/pkg/UserControllerTest.java
reason: "all strategy items already covered by existing tests"
already_covered:
  - item: "createUser(User): delegates to userService.createUser then getUser"
    covered_by: "shouldReturnCreatedUserWhenCreateUserIsCalledWithValidUser"
```
