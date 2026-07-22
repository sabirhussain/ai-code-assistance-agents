---
name: write-failing-test
description: >
  Generate failing JUnit 5 unit tests for a given feature, class, or method.
  RED phase only — tests will fail because implementation does not exist yet.
---

# Skill: Write Failing Unit Test (RED Phase)

## Token Economy Rules (ALWAYS FOLLOW FIRST)

**Critical: Follow these rules to minimize token usage:**

1. **CACHE CONFIG** — Read `.github/copilot-config.yml` and `.github/test-patterns.yml` ONCE at session start, cache
   values, never re-read
2. **NEVER scan entire repository** — Only read files explicitly requested by user or required for pattern matching
3. **NEVER use semantic_search** — Unless user explicitly requests "find" or "search across codebase"
4. **NEVER read dependency chains** — Only read files directly in scope (the class under test)
5. **PROGRESSIVE DISCLOSURE** — Ask ONLY required fields (Feature, Dependencies); ask optional fields ONLY if user
   types 'configure' or 'options'
6. **STOP after sufficient context** — Maximum 3 file reads unless user requests more research
7. **USE YAML PATTERNS** — Load patterns from `.github/test-patterns.yml` instead of interpreting prose examples

## Role

You are a world-class software engineer specializing in TDD. Generate **unit tests only** — never implementation code.

## TDD Philosophy

- **RED** (YOUR JOB): Write failing tests that reference non-existent code
- **GREEN** (USER'S JOB): User writes minimal implementation to pass
- **REFACTOR** (USER'S JOB): User improves code quality

## Input Format

Provide the following — fields marked REQUIRED must be supplied; optional fields improve output quality and have smart
defaults:

```
Feature: <description or user story>                              ← REQUIRED
SUT Type: controller|service|component|repository                 ← REQUIRED (inferred from Feature if omitted)
Class: <ClassName>                                                ← optional (derived from Feature + SUT Type if omitted)
Method: <methodName(param: Type): ReturnType>                     ← optional (default: all public methods inferred from Class)
Dependencies: <Dependency1, Dependency2>                          ← REQUIRED (or `skip` to infer defaults from SUT Type)
Parameterized: yes | no                                           ← optional (default: no; yes generates @ParameterizedTest variants)
Test location: <optional override>                                ← optional (default: <test_path>/<sut-type-package>, pick test_path from copilot-config.yml)
```

**Note on class naming by SUT Type:**

- `controller` → Test class: `<Feature>ControllerTest` (tests the Impl, field typed as interface)
- `service` → Test class: `<Feature>ServiceTest` (tests the ServiceImpl, field typed as interface)
- `component` → Test class: `<Feature>ComponentTest` or `<Feature>HelperTest` or `<Feature>UtilsTest`
- `repository` → Test class: `<Feature>RepositoryTest` (tests the RepositoryImpl, field typed as interface if
  applicable)
- **Important:** Test class names **NEVER** include "Impl" suffix — test the interface with impl-typed fields (e.g.,
  `private UserService userService = new UserServiceImpl(...)`).
- **Spring Repository interfaces** (e.g., `UserRepository extends JpaRepository`) are **not** tested at unit level —
  tested via integration tests

**SUT Type inference from Feature keywords:**
When Class is missing, infer SUT Type from Feature description:

- Contains: "endpoint", "HTTP", "GET", "POST", "controller", "request", "response" → `controller`
- Contains: "service", "orchestrat", "business", "rule", "validate", "transact" → `service`
- Contains: "query", "fetch", "load", "persist", "database", "table", "entity" → `repository`
- Contains: "format", "convert", "calculate", "trim", "parse", "util", "helper" → `component`
- Default (uncertain) → infer as `service`

#### Dependency Inference Rules

Before asking the user about dependencies, infer a candidate list from **SUT Type + Feature keywords + Class name**.
Show this inferred list in the question — never ask a blank prompt.

| SUT Type     | Feature / Class keywords                        | Inferred mock candidates                            |
|--------------|-------------------------------------------------|-----------------------------------------------------|
| `service`    | any                                             | `*Repository` matching the domain noun in Class     |
| `service`    | "email", "notification", "send"                 | + `EmailSender` / `NotificationSender`              |
| `service`    | "token", "jwt", "auth"                          | + `TokenGenerator` / `JwtProvider`                  |
| `service`    | "password", "hash", "encode"                    | + `PasswordEncoder`                                 |
| `service`    | "event", "publish"                              | + `ApplicationEventPublisher`                       |
| `controller` | any                                             | Service interface matching the domain noun in Class |
| `repository` | any                                             | `EntityManager` (JPA) or `JdbcTemplate` (JDBC)      |
| `component`  | "serial", "json", "marshal", "convert", "parse" | `ObjectMapper`                                      |
| `component`  | "cache", "redis"                                | `RedisTemplate`                                     |
| `component`  | "http", "client", "rest", "call"                | `RestClient` / `WebClient` / `RestTemplate`         |
| any          | Class constructor params visible in source      | Each constructor param type (best-effort hint)      |

**Rule:** Always produce at least one inferred candidate. If nothing matches, fall back to the most common type-default
(Service → `*Repository`; Controller → `*Service`; Repository → `EntityManager`; Component → none).

### When Inputs Are Incomplete

**Trigger rule:** If any optional field (`SUT Type`, `Class`, `Dependencies`, `Parameterized`, `Test location`) is
absent, ask each missing field as a numbered question **before generating tests**. Always ask `SUT Type` first (if
absent) — all other defaults depend on it.

#### Skip keywords

| Keyword    | Effect                                                                        |
|------------|-------------------------------------------------------------------------------|
| `skip`     | Accept the inferred/default value for the current question, move to the next  |
| `skip all` | Accept inferred/default values for all remaining unanswered questions at once |

For **Dependencies** specifically, `skip` means **"confirm the inferred list as-is"** — not "use none".

#### Modification verbs for Dependencies

When answering the Dependencies question the user may:

| Input                     | Effect                                               |
|---------------------------|------------------------------------------------------|
| `skip`                    | Confirm the inferred list unchanged                  |
| `+ Dep1, Dep2`            | Add to the inferred list                             |
| `- Dep1`                  | Remove one or more inferred entries                  |
| `Dep1, Dep2` (plain list) | Replace the inferred list entirely                   |
| `none`                    | Clear all inferred deps — generate no `@Mock` fields |

#### Defaults for each skippable field

| Field           | Default when skipped                                                                                                                                       |
|-----------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `SUT Type`      | **Inferred from Feature keywords** (see inference rules above). If uncertain, defaults to `service`.                                                       |
| `Class`         | Derived from `Feature` + inferred `SUT Type`: extract noun → PascalCase + type-suffix **without Impl** (e.g., `UserService`, not `UserServiceImpl`)        |
| `Dependencies`  | **Inferred from SUT Type + Feature keywords + Class name** (see Dependency Inference Rules). `skip` confirms the inferred list — never silently uses none. |
| `Parameterized` | `no`                                                                                                                                                       |
| `Test location` | **Derived from SUT Type** (only if not provided). Pattern: `<package.test_path>/<SUT-type-subpackage>`                                                     |

**Package derivation by SUT Type (when test location not provided):**

- `service` → `src/test/java/<base_package>.service`
- `controller` | `rest` → `src/test/java/<base_package>.resource` (or `.controller`)
- `repository` → `src/test/java/<base_package>.repository`
- `component` → `src/test/java/<base_package>.component`
- `util` | `utils` → `src/test/java/<base_package>.util`
- `helper` → `src/test/java/<base_package>.helper`

Example: If Feature is "Send password-reset email", inferred SUT Type is `service`, then default test location =
`<test_path>/service`, pick test_path from copilot-config.yml

#### Question template

**If `Class` is provided:** Skip to question 3 (Dependencies). SUT Type and Class are already determined.

**If `Class` is missing:** Ask SUT Type first (showing inferred default), then ask Class, then Dependencies.

```
Before I generate the tests, I have a few questions.
Reply with your answer, or type `skip` to confirm the inferred default for that question,
or type `skip all` to confirm inferred defaults for all remaining questions.

1. **SUT Type** — What type of component are you testing?
   *(controller | service | component | repository; default: inferred as `<InferredType>` from Feature)*

2. **Class** — What is the name of the class under test?
   *(default: derived from Feature as `<InferredClassName>` — **without** Impl suffix)*

3. **Dependencies** — I inferred these collaborators to mock: `<InferredDep1>`, `<InferredDep2>`
   Type `skip` to confirm as-is, `+ Dep` to add, `- Dep` to remove, a plain list to replace, or `none` to clear all.

4. **Parameterized** — Should I generate data-driven / parameterized tests?
   *(yes | no; default: no)*

5. **Test location** — Where should the test file be placed?
   *(default: `<test_path from copilot-config.yml>/<sut-type-subpackage>`)*
```

After the user replies (or skips), confirm the resolved inputs before generating tests:

```
✅ Resolved inputs:
  Feature:       <value>
  SUT Type:      <value>         (inferred | provided)
  Class:         <value>         (derived | provided)
  Dependencies:  <value>         (inferred | confirmed | modified | provided | none)
  Parameterized: <value>
  Test location: <value>         (derived from SUT Type | provided | default from copilot-config.yml)
```

#### Worked example — Service Implementation

**User provides:**

```
Feature: Send password-reset email to a registered user
```

**Agent infers SUT Type as `service`, Class as `PasswordResetService`, deps as `UserRepository, EmailSender`, and asks:
**

```
Before I generate the tests, I have a few questions.
Reply with your answer, type `skip` for that question, or `skip all` to confirm all inferred defaults.

1. **SUT Type** — What type of component are you testing?
   *(default: inferred as `service` from Feature)*

2. **Class** — What is the name of the class under test?
   *(default: derived from Feature as `PasswordResetService`)*

3. **Dependencies** — I inferred these collaborators to mock: `UserRepository`, `EmailSender`
   Type `skip` to confirm as-is, `+ Dep` to add, `- Dep` to remove, a plain list to replace, or `none` to clear all.

4. **Parameterized** — Should I generate data-driven / parameterized tests?
   *(yes | no; default: no)*

5. **Test location** — Where should the test file be placed?
   *(default: `src/test/java/io/xprevel/sample/groq_ai/service`)*
```

**User replies:**

```
1. skip
2. skip
3. + NotificationAuditLogger
skip all
```

**Agent confirms, then generates tests:**

```
✅ Resolved inputs:
  Feature:       Send password-reset email to a registered user
  SUT Type:      service                                              (inferred)
  Class:         PasswordResetService                                 (derived)
  Dependencies:  UserRepository, EmailSender, NotificationAuditLogger (modified — added: NotificationAuditLogger)
  Parameterized: no                                                   (default)
  Test location: src/test/java/io/xprevel/sample/groq_ai/service      (derived from SUT Type)

Generating failing tests…
```

#### Worked example — Repository Implementation

**User provides:**

```
Feature: Query active users from the database by department
SUT Type: repository
```

**Agent infers Class as `UserRepository`, deps as `EntityManager`, and asks:**

```
Before I generate the tests, I have a few questions.
Reply with your answer, type `skip` for that question, or `skip all` to confirm all inferred defaults.

1. **Class** — What is the name of the class under test?
   *(default: derived from Feature as `UserRepository`)*

2. **Dependencies** — I inferred these collaborators to mock: `EntityManager`
   Type `skip` to confirm as-is, `+ Dep` to add, `- Dep` to remove, a plain list to replace, or `none` to clear all.

3. **Parameterized** — Should I generate data-driven / parameterized tests?
   *(yes | no; default: no)*

4. **Test location** — Where should the test file be placed?
   *(default: `src/test/java/io/xprevel/sample/groq_ai/repository`)*
```

**User replies:**

```
1. skip
2. - EntityManager
   + JdbcTemplate
skip all
```

**Agent confirms, then generates tests:**

```
✅ Resolved inputs:
  Feature:       Query active users from the database by department
  SUT Type:      repository                                            (provided)
  Class:         UserRepository                                        (derived)
  Dependencies:  JdbcTemplate                                          (modified — removed: EntityManager, added: JdbcTemplate)
  Parameterized: no                                                    (default)
  Test location: src/test/java/io/xprevel/sample/groq_ai/repository   (derived from SUT Type)

Generating failing tests…
```

## Test Requirements

### Structure

- `@ExtendWith(MockitoExtension.class)` — never `@SpringBootTest`
- All dependencies injected via `@Mock` + `@InjectMocks`
- Test method naming: `should<ExpectedBehavior>When<Condition>()`
- Follow AAA pattern: `// Arrange`, `// Act`, `// Assert`

### Layer-Specific Unit Test Strategy

**Load test patterns from `.github/test-patterns.yml` → `test_patterns.{sut_type}` for:**

- Field instantiation pattern
- Required imports
- Setup requirements
- Default mock dependencies
- Test structure (Arrange/Act/Assert)
- Validation rules

Unit-test generation differs by SUT Type (System Under Test). Patterns are defined in YAML for consistency.

#### Controller (REST Endpoint Implementation)

**Pattern:** Load from `test_patterns.controller` in `.github/test-patterns.yml`

**Key requirements:**

- Use MockMvc with standalone setup
- Field typed as interface, instantiated with impl + mocked deps
- Mock service dependencies
- Test HTTP status codes, response body, validation

**Validation:** Must contain MockMvc, @BeforeEach setup, MockMvcBuilders.standaloneSetup. Must NOT contain @InjectMocks,
@SpringBootTest, WebTestClient.

#### Service Implementation

**Pattern:** Load from `test_patterns.service` in `.github/test-patterns.yml`

**Key requirements:**

- Field typed as interface, instantiated with impl + mocked constructor deps
- Mock repository dependencies
- Verify method calls with ArgumentCaptor and verify()
- Test business rules, validations, exception handling

**Validation:** Must contain @Mock, AAA comments, assertThat. Must NOT contain @InjectMocks, @SpringBootTest,
@Transactional.

#### Component / Helper / Utils

**Pattern:** Load from `test_patterns.component` in `.github/test-patterns.yml`

**Key requirements:**

- Direct unit test
- Minimal mocking (only external dependencies)
- Focus on pure logic and boundary conditions

#### Repository (Custom Database Access Implementation)

**Pattern:** Load from `test_patterns.repository` in `.github/test-patterns.yml`

**Key requirements:**

- Mock EntityManager (JPA) or JdbcTemplate (JDBC)
- Field typed as interface, instantiated with impl + mocked persistence mechanism
- Test query logic, parameter binding, result mapping
- Never test with real database (unit test only)

**Note:** Spring Repository interfaces (JpaRepository, CrudRepository) are NOT tested at unit level — tested via
integration tests.

#### Dependency Inference

**Load from `.github/test-patterns.yml` → `dependency_inference_rules`**

Default inference by SUT Type:

- `service` → {Domain}Repository
- `service` + (email|notification) keywords → + EmailSender
- `service` + (token|jwt|auth) keywords → + TokenGenerator/JwtProvider
- `service` + (password|hash) keywords → + PasswordEncoder
- `controller` → {Domain}Service
- `repository:jpa` → EntityManager
- `repository:jdbc` → JdbcTemplate
- `component` + (json|serial) keywords → ObjectMapper
- `component` + (cache|redis) keywords → RedisTemplate

### Nested Classes & Feature-Split Files (ALWAYS apply)

#### Rule 1 — Group every feature/method under its own `@Nested` class

- Every distinct method/feature under test MUST have a dedicated `@Nested` inner class
- Annotate every nested class with `@DisplayName("<FeatureName>")` for readable IDE/report output
- `@Mock`, `@InjectMocks`, and shared fixtures (e.g., `validUser()`) stay at the **outer** class level only — never
  duplicated inside nested classes
- Sub-features (e.g., validation) get their own deeper `@Nested` class inside the parent nested class

**Canonical structure:**

```java

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;
    @InjectMocks
    private UserService userService;

    // shared fixtures
    private static UserVO validUser() { ...}

    @Nested
    @DisplayName("Create User")
    class CreateUserTests {
        @Test
        void shouldReturnCreatedUserWhenUserIsValid() { ...}

        @Nested
        @DisplayName("Validation")
        class ValidationTests {
            @ParameterizedTest
            void shouldThrowExceptionWhenEmailIsInvalid() { ...}
        }
    }

    @Nested
    @DisplayName("Delete User")
    class DeleteUserTests {
        @Test
        void shouldDeleteUserWhenUserExists() { ...}
    }

    @Nested
    @DisplayName("Get User")
    class GetUserTests {
        @Test
        void shouldReturnUserWhenUserIdExists() { ...}
    }
}
```

#### Rule 2 — Split into a dedicated file when a `@Nested` class reaches 8+ test methods

- Extract the nested class to its own top-level file: `<ClassName><Feature>Test.java`
    - e.g. `UserServiceCreateUserTest.java`, `UserServiceDeleteUserTest.java`
- The extracted class carries its own `@ExtendWith(MockitoExtension.class)`, `@Mock`, and `@InjectMocks`
- The original `UserServiceTest.java` retains the remaining nested groups
- **Never** flatten tests back to a list — always maintain nested or split structure

| Feature       | Dedicated Class                  |
|---------------|----------------------------------|
| Create user   | `UserServiceCreateUserTest.java` |
| Delete user   | `UserServiceDeleteUserTest.java` |
| Update user   | `UserServiceUpdateUserTest.java` |
| List / search | `UserServiceListUsersTest.java`  |
| Validation    | `UserServiceValidationTest.java` |

#### Rule 3 — Visual hierarchy reference

```
UserServiceTest.java              ← outer shell: mocks, shared fixtures, @Nested groups
  @Nested CreateUserTests         ← create() tests
    @Nested ValidationTests       ← create() validation sub-tests
  @Nested GetUserTests            ← getUser() tests
  @Nested DeleteUserTests         ← deleteUser() tests  → split to own file when ≥ 8 methods
UserServiceCreateUserTest.java    ← extracted when CreateUserTests ≥ 8 methods
UserServiceDeleteUserTest.java    ← extracted when DeleteUserTests ≥ 8 methods
```

### Coverage

Every generated test file **MUST** include at least one test from **each** of the three categories below.
**Omitting any category is a generation error.**

#### ✅ Success (Happy Path)

Tests that verify the system returns the correct result when all inputs are valid and dependencies behave as expected.

**Checklist — generate at least one test for each that applies:**

- Returns the expected value / object
- Calls the correct dependency method with the correct arguments (`ArgumentCaptor`)
- Calls each dependency exactly the expected number of times (`verify(..., times(n))`)

**Example test name:** `shouldReturnTokenWhenCredentialsAreValid()`

#### ❌ Failure (Error Scenarios)

Tests that verify the system throws the correct exception with the correct message when something goes wrong.

**Checklist — generate at least one test for each that applies:**

- Dependency throws a runtime exception → propagates correctly
- Business rule violated → throws domain exception with correct message
- Required resource not found → throws not-found exception
- No interaction with dependency when pre-condition fails (`verifyNoInteractions`)

**Example test name:** `shouldThrowExceptionWhenUserDoesNotExist()`

#### ⚠️ Edge Cases

Tests that probe boundary conditions, blank/null inputs, and atypical but valid inputs.

**Checklist — generate at least one test for each that applies:**

- `null` input arguments
- Blank / empty string inputs (`@NullAndEmptySource`, `@ValueSource`)
- Empty collections
- Boundary values (min, max, zero, negative)
- Duplicate / already-exists scenarios

**Example test name:** `shouldThrowExceptionWhenUsernameIsBlankOrNull()`

#### Mandatory nesting rule

When a feature's `@Nested` class contains **3 or more tests in total** across all categories, each category MUST become
its own deeper `@Nested` class with `@DisplayName`:

```java

@Nested
@DisplayName("Login")
class LoginTests {

    @Nested
    @DisplayName("Success")
    class SuccessTests {
        @Test
        void shouldReturnTokenWhenCredentialsAreValid() { ...}

        @Test
        void shouldPassCorrectUserToTokenGeneratorWhenLoginSucceeds() { ...}
    }

    @Nested
    @DisplayName("Failure")
    class FailureTests {
        @Test
        void shouldThrowExceptionWhenUserDoesNotExist() { ...}

        @Test
        void shouldThrowExceptionWhenPasswordIsIncorrect() { ...}
    }

    @Nested
    @DisplayName("Edge Cases")
    class EdgeCaseTests {
        @ParameterizedTest
        void shouldThrowExceptionWhenUsernameIsBlankOrNull(String username) { ...}
    }
}
```

When a feature has **fewer than 3 tests** in total, flat comments are acceptable:

```java
// --- Success ---
// --- Failure ---
// --- Edge Cases ---
```

### Assertions

**Load assertion library patterns from `.github/test-patterns.yml` → `assertion_libraries`**

**Selection rule:** Check pom.xml for `assertj-core` OR `spring-boot-starter-test`

**When AssertJ available (preferred):**

- Equality: `assertThat(result).isEqualTo(expected)`
- Null check: `assertThat(result).isNotNull()`
- Collections: `assertThat(list).containsExactly(...)`
- Exceptions: `assertThatThrownBy(() -> ...).isInstanceOf(X.class).hasMessage("...")`

**When AssertJ NOT available (JUnit 5 fallback):**

- Equality: `assertEquals(expected, actual)`
- Null check: `assertNotNull(result)`
- Exceptions: `assertThrows(X.class, () -> ...)`

Never use `assertTrue(result == x)` when AssertJ is available — always use fluent assertions.

### Data-Driven Tests (Parameterized)

When a feature has multiple input/output combinations, use JUnit 5 parameterized tests:

- Use `@ParameterizedTest` + `@MethodSource` for complex objects
- Use `@ParameterizedTest` + `@CsvSource` for simple value pairs
- Use `@ParameterizedTest` + `@NullAndEmptySource` for null/empty edge cases
- Test method naming: `should<ExpectedBehavior>WhenGiven<InputType>()`

**When to prefer parameterized over individual tests:**

- Same logic, multiple input/output pairs (e.g., validation rules, calculations)
- Boundary value testing (min, max, zero, negative)
- Null + empty + blank string variants
- Enum-driven behavior differences

**Example — `@CsvSource` for boundary values:**

```java

@ParameterizedTest(name = "input={0}, expected={1}")
@CsvSource({
        "0,   ZERO",
        "1,   POSITIVE",
        "-1,  NEGATIVE",
        "100, POSITIVE"
})
void shouldClassifyNumberWhenGivenInput(int input, String expectedCategory) {
    // Act
    String result = classifier.classify(input);

    // Assert
    assertThat(result).isEqualTo(expectedCategory);
}
```

**Example — `@MethodSource` for complex objects:**

```java
static Stream<Arguments> invalidLoginInputs() {
    return Stream.of(
            Arguments.of(null, "secret", "Username must not be null"),
            Arguments.of("john", null, "Password must not be null"),
            Arguments.of("", "secret", "Username must not be blank"),
            Arguments.of("john", "", "Password must not be blank")
    );
}

@ParameterizedTest(name = "username={0}, password={1}")
@MethodSource("invalidLoginInputs")
void shouldThrowExceptionWhenGivenInvalidCredentials(
        String username, String password, String expectedMessage) {
    assertThatThrownBy(() -> authenticationService.login(username, password))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessage(expectedMessage);
}
```

**Example — `@NullAndEmptySource` for blank string variants:**

```java

@ParameterizedTest
@NullAndEmptySource
@ValueSource(strings = {"  ", "\t", "\n"})
void shouldThrowExceptionWhenUsernameIsBlankOrNull(String username) {
    assertThatThrownBy(() -> authenticationService.login(username, "secret"))
            .isInstanceOf(IllegalArgumentException.class);
}
```

## Example

**Input:**

```
Feature: User authentication — validate credentials and return a token
Class: AuthenticationService
Method: login(username: String, password: String): Token
Dependencies: UserRepository, TokenGenerator
Parameterized: yes
```

**Output 1 — Test File: `AuthenticationServiceTest.java`**

```java
// Package is read from copilot-config.yml → package.base
package

<base_package>;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.stream.Stream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthenticationServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private TokenGenerator tokenGenerator;

    @InjectMocks
    private AuthenticationService authenticationService;

    // --- Shared parameterized data ---

    static Stream<Arguments> invalidLoginInputs() {
        return Stream.of(
                Arguments.of(null, "secret", "Username must not be null"),
                Arguments.of("john", null, "Password must not be null"),
                Arguments.of("", "secret", "Username must not be blank"),
                Arguments.of("john", "", "Password must not be blank")
        );
    }

    @Nested
    @DisplayName("Login")
    class LoginTests {

        @Nested
        @DisplayName("Success")
        class SuccessTests {

            @Test
            void shouldReturnTokenWhenCredentialsAreValid() {
                // Arrange
                var user = new User("john", "encoded_password");
                var expectedToken = new Token("jwt-abc-123");
                when(userRepository.findByUsername("john")).thenReturn(Optional.of(user));
                when(tokenGenerator.generate(user)).thenReturn(expectedToken);

                // Act
                Token result = authenticationService.login("john", "secret");

                // Assert
                assertThat(result).isEqualTo(expectedToken);
            }

            @Test
            void shouldPassCorrectUserToTokenGeneratorWhenLoginSucceeds() {
                // Arrange
                var user = new User("john", "encoded_password");
                when(userRepository.findByUsername("john")).thenReturn(Optional.of(user));
                when(tokenGenerator.generate(any())).thenReturn(new Token("token"));
                var captor = ArgumentCaptor.forClass(User.class);

                // Act
                authenticationService.login("john", "secret");

                // Assert
                verify(tokenGenerator).generate(captor.capture());
                assertThat(captor.getValue().getUsername()).isEqualTo("john");
            }
        }

        @Nested
        @DisplayName("Failure")
        class FailureTests {

            @Test
            void shouldThrowExceptionWhenUsernameDoesNotExist() {
                // Arrange
                when(userRepository.findByUsername("unknown")).thenReturn(Optional.empty());

                // Act & Assert
                assertThatThrownBy(() -> authenticationService.login("unknown", "secret"))
                        .isInstanceOf(AuthenticationException.class)
                        .hasMessage("User not found");
            }

            @ParameterizedTest(name = "username=''{0}'' password=''{1}'' => {2}")
            @MethodSource("io.xprevel.sample.groq_ai.AuthenticationServiceTest#invalidLoginInputs")
            void shouldThrowExceptionWhenGivenInvalidCredentials(
                    String username, String password, String expectedMessage) {
                assertThatThrownBy(() -> authenticationService.login(username, password))
                        .isInstanceOf(IllegalArgumentException.class)
                        .hasMessage(expectedMessage);
            }
        }

        @Nested
        @DisplayName("Edge Cases")
        class EdgeCaseTests {

            @ParameterizedTest
            @NullAndEmptySource
            @ValueSource(strings = {"  ", "\t", "\n"})
            void shouldThrowExceptionWhenUsernameIsBlankOrNull(String username) {
                assertThatThrownBy(() -> authenticationService.login(username, "secret"))
                        .isInstanceOf(IllegalArgumentException.class);
            }
        }
    }
}
```

**Output 2 — PIT Mutation Testing Snippet (reference only, do NOT apply):**

```xml
<!-- Add to pom.xml <build><plugins> section — DO NOT apply automatically -->
<plugin>
    <groupId>org.pitest</groupId>
    <artifactId>pitest-maven</artifactId>
    <version>1.17.0</version>
    <dependencies>
        <dependency>
            <groupId>org.pitest</groupId>
            <artifactId>pitest-junit5-plugin</artifactId>
            <version>1.2.1</version>
        </dependency>
    </dependencies>
    <configuration>
        <targetClasses>
            <param>io.xprevel.sample.groq_ai.*</param>
        </targetClasses>
        <targetTests>
            <param>io.xprevel.sample.groq_ai.*Test</param>
        </targetTests>
        <mutators>
            <mutator>STRONGER</mutator>
        </mutators>
        <outputFormats>
            <outputFormat>HTML</outputFormat>
        </outputFormats>
    </configuration>
</plugin>
```

Run mutation tests with:

```
mvn org.pitest:pitest-maven:mutationCoverage
```