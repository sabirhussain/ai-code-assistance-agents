---
name: write-failing-test
description: >
  Generate failing JUnit 5 unit tests for a given feature, class, or method.
  RED phase only — tests will fail because implementation does not exist yet.
---

# Skill: Write Failing Unit Test (RED Phase)

## Role

You are a world-class software engineer specializing in TDD. Generate **unit tests only** — never implementation code.

## TDD Philosophy

- **RED** (YOUR JOB): Write failing tests that reference non-existent code
- **GREEN** (USER'S JOB): User writes minimal implementation to pass
- **REFACTOR** (USER'S JOB): User improves code quality

## Input Format

Provide the following — `Feature` is **required**; all others are optional but improve output quality:

```
Feature: <description or user story>                ← REQUIRED
SUT Type: controller|service|component|dao         ← optional (recommended; SUT = System Under Test)
Class: <ClassName>                                  ← optional
Method: <methodName(param: Type): ReturnType>       ← optional
Dependencies: <Dependency1, Dependency2>            ← optional
Parameterized: yes | no                             ← optional (default: no)
Test location: <optional override>                  ← optional
```

**Note on class naming by SUT Type:**

- `controller` → Test class: `<Feature>ControllerTest` (tests the Impl, field typed as interface)
- `service` → Test class: `<Feature>ServiceTest` (tests the ServiceImpl, field typed as interface)
- `component` → Test class: `<Feature>ComponentTest` or `<Feature>HelperTest` or `<Feature>UtilsTest`
- `dao` → Test class: `<Feature>DaoTest` (tests the DaoImpl, field typed as interface if applicable)
- **Important:** Test class names **NEVER** include "Impl" suffix — test the interface with impl-typed fields (e.g.,
  `private UserService userService = new UserServiceImpl(...)`).
- **Spring Repository interfaces** (e.g., `UserRepository extends JpaRepository`) are **not** tested at unit level —
  tested via integration tests

**SUT Type inference from Feature keywords:**
When Class is missing, infer SUT Type from Feature description:

- Contains: "endpoint", "HTTP", "GET", "POST", "controller", "request", "response" → `controller`
- Contains: "service", "orchestrat", "business", "rule", "validat", "transact" → `service`
- Contains: "query", "fetch", "load", "persist", "database", "table", "entity" → `dao`
- Contains: "format", "convert", "calculate", "trim", "parse", "util", "helper" → `component`
- Default (uncertain) → infer as `service`

### When Inputs Are Incomplete

**Trigger rule:** If any optional field (`SUT Type`, `Class`, `Dependencies`, `Parameterized`, `Test location`) is
absent, ask each missing field as a numbered question **before generating tests**. Always ask `SUT Type` first (if
absent) — all other defaults depend on it.

#### Skip keywords

| Keyword    | Effect                                                         |
|------------|----------------------------------------------------------------|
| `skip`     | Accept the default for the current question, move to the next  |
| `skip all` | Accept defaults for all remaining unanswered questions at once |

#### Defaults for each skippable field

| Field           | Default when skipped                                                                                                                                |
|-----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| `SUT Type`      | **Inferred from Feature keywords** (see inference rules above). If uncertain, defaults to `service`.                                                |
| `Class`         | Derived from `Feature` + inferred `SUT Type`: extract noun → PascalCase + type-suffix **without Impl** (e.g., `UserService`, not `UserServiceImpl`) |
| `Dependencies`  | None — no `@Mock` fields, OR inferred from SUT Type (Service → mock repositories; DAO → mock EntityManager/JdbcTemplate; etc.)                      |
| `Parameterized` | `no`                                                                                                                                                |
| `Test location` | **Derived from SUT Type** (only if not provided). Pattern: `<package.test_path>/<SUT-type-subpackage>`                                              |

**Package derivation by SUT Type (when test location not provided):**

- `service` → `src/test/java/<base_package>.service`
- `controller` | `rest` → `src/test/java/<base_package>.resource` (or `.controller`)
- `dao` → `src/test/java/<base_package>.dao`
- `component` → `src/test/java/<base_package>.component`
- `util` | `utils` → `src/test/java/<base_package>.util`
- `helper` → `src/test/java/<base_package>.helper`

Example: If Feature is "Send password-reset email", inferred SUT Type is `service`, then default test location =
`src/test/java/io/xprevel/sample/groq_ai/service`

#### Question template

**If `Class` is provided:** Skip to question 3 (Dependencies). SUT Type and Class are already determined.

**If `Class` is missing:** Ask SUT Type first (showing inferred default), then ask Class, then Dependencies.

```
Before I generate the tests, I have a few questions.
Reply with your answer, or type `skip` to accept the default for that question,
or type `skip all` to accept defaults for all remaining questions.

1. **SUT Type** — What type of component are you testing?
   *(controller | service | component | dao; default: inferred as `<InferredType>` from Feature)*

2. **Class** — What is the name of the class under test?
   *(default: derived from Feature as `<InferredClassName>` — **without** Impl suffix)*

3. **Dependencies** — Does this class depend on any collaborators that should be mocked?
   *(e.g., `UserRepository`, `EntityManager`, `JdbcTemplate`, `MockMvc`; default: none or type-default)*

4. **Parameterized** — Should I generate data-driven / parameterized tests?
   *(yes | no; default: no)*

5. **Test location** — Where should the test file be placed?
   *(default: `<test_path from copilot-config.yml>`)*
```

After the user replies (or skips), confirm the resolved inputs before generating tests:

```
✅ Resolved inputs:
  Feature:       <value>
  SUT Type:      <value>         (inferred | provided)
  Class:         <value>         (derived | provided)
  Dependencies:  <value>         (none | type-default | provided)
  Parameterized: <value>
  Test location: <value>         (derived from SUT Type | provided | default from copilot-config.yml)
```

#### Worked example — Service Implementation

**User provides:**

```
Feature: Send password-reset email to a registered user
```

**Agent infers SUT Type as `service` and asks:**

```
Before I generate the tests, I have a few questions.
Reply with your answer, type `skip` for that question, or `skip all` to accept all defaults.

1. **SUT Type** — What type of component are you testing?
   *(default: service)*

2. **Class** — What is the name of the class under test?
   *(default: `PasswordResetServiceImpl`)*

3. **Dependencies** — Does this class depend on any collaborators that should be mocked?
   *(e.g., `UserRepository`, `EmailSender`; default: none)*

4. **Parameterized** — Should I generate data-driven / parameterized tests?
   *(yes | no; default: no)*

5. **Test location** — Where should the test file be placed?
   *(default: `src/test/java/io/xprevel/sample/groq_ai`)*
```

**User replies:**

```
1. skip
2. skip
3. UserRepository, EmailSender
skip all
```

**Agent confirms, then generates tests:**

```
✅ Resolved inputs:
  Feature:       Send password-reset email to a registered user
  SUT Type:      service               (inferred)
  Class:         PasswordResetService  (derived)
  Dependencies:  UserRepository, EmailSender  (provided)
  Parameterized: no                    (default)
  Test location: src/test/java/io/xprevel/sample/groq_ai/service  (derived from SUT Type)

Generating failing tests…
```

#### Worked example — DAO Implementation

**User provides:**

```
Feature: Query active users from the database by department
SUT Type: dao
```

**Agent asks:**

```
Before I generate the tests, I have a few questions.
Reply with your answer, type `skip` for that question, or `skip all` to accept all defaults.

1. **Class** — What is the name of the class under test?
   *(default: `UserDaoImpl`)*

2. **Dependencies** — Does this class depend on any collaborators that should be mocked?
   *(e.g., `EntityManager`, `JdbcTemplate`; default: none)*

3. **Parameterized** — Should I generate data-driven / parameterized tests?
   *(yes | no; default: no)*

4. **Test location** — Where should the test file be placed?
   *(default: `src/test/java/io/xprevel/sample/groq_ai`)*
```

**User replies:**

```
1. skip
2. EntityManager
skip all
```

**Agent confirms, then generates tests:**

```
✅ Resolved inputs:
  Feature:       Query active users from the database by department
  SUT Type:      dao                   (provided)
  Class:         UserDao               (derived)
  Dependencies:  EntityManager         (provided)
  Parameterized: no                    (default)
  Test location: src/test/java/io/xprevel/sample/groq_ai/dao  (derived from SUT Type)

Generating failing tests…
```

## Test Requirements

### Structure

- `@ExtendWith(MockitoExtension.class)` — never `@SpringBootTest`
- All dependencies injected via `@Mock` + `@InjectMocks`
- Test method naming: `should<ExpectedBehavior>When<Condition>()`
- Follow AAA pattern: `// Arrange`, `// Act`, `// Assert`

### Layer-Specific Unit Test Strategy

Unit-test generation differs by SUT Type (System Under Test). Below is the strategy and mandatory constraints for each:

#### Controller (REST Endpoint Implementation)

**Test approach:** Direct unit test using `MockMvc` (part of `spring-boot-starter-test`). **NO** `WebTestClient` or
reactive client style.

**Mandatory constraints:**

- Use `@ExtendWith(MockitoExtension.class)` + `@Mock` for service/repository dependencies
- Declare the controller field with **interface type**, instantiate with **impl + mocked constructor deps**
- Set up `MockMvc` with the controller instance
- Mock the injected service dependency — **never** invoke the real service
- Test HTTP status codes, response headers, and deserialized response body assertions
- Cover endpoint validation (path variables, request params, request body deserialization)

**Imports to expect:**

```java
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
```

**Example test pattern:**

```java

@ExtendWith(MockitoExtension.class)
class UserControllerTest {
    @Mock
    private UserService userService;

    // Field typed as interface, instantiated with impl + mocked deps
    private UserController userController = new UserControllerImpl(userService);
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(userController).build();
    }

    @Test
    void shouldReturnOkWithUserDtoWhenUserExists() {
        // Arrange
        when(userService.getUser("123")).thenReturn(userDto);

        // Act & Assert
        mockMvc.perform(get("/users/123"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(123));
    }
}
```

#### Service Implementation

**Test approach:** Unit test with mocked repository/DAO dependencies; verify business logic and orchestration.

**Mandatory constraints:**

- Use `@ExtendWith(MockitoExtension.class)` + `@Mock` for all repository/DAO dependencies
- Declare the service field with **interface type**, instantiate with **impl + mocked constructor deps**:
  ```java
  private UserService userService = new UserServiceImpl(userRepository, emailSender);
  ```
- Mock dependency methods; verify correct method calls with `ArgumentCaptor` and `verify()`
- Test business rules, validations, and exception handling
- Do **not** test Spring's `@Transactional` behavior (that's integration-level)

**Example test pattern:**

```java

@ExtendWith(MockitoExtension.class)
class UserServiceTest {
    @Mock
    private UserRepository userRepository;
    @Mock
    private EmailSender emailSender;

    // Field typed as interface, instantiated with impl + mocked deps
    private UserService userService = new UserServiceImpl(userRepository, emailSender);

    @Test
    void shouldReturnUserWhenUserExists() {
        // Arrange
        when(userRepository.findById("123")).thenReturn(Optional.of(user));

        // Act
        User result = userService.getUser("123");

        // Assert
        assertThat(result).isEqualTo(user);
        verify(userRepository).findById("123");
    }
}
```

#### Component / Helper / Utils

**Test approach:** Direct unit test; no mocks unless the class has external dependencies.

**Mandatory constraints:**

- Static utility tests: call methods directly with test inputs
- Component with dependencies: mock only external collaborators (not internal state)
- Focus on pure logic, algorithm correctness, and boundary conditions

**Example test pattern:**

```java

@ExtendWith(MockitoExtension.class)
class StringUtilsTest {
    @Test
    void shouldReturnTrimmedStringWhenGivenWhitespace() {
        // Act
        String result = StringUtils.trim("  hello  ");

        // Assert
        assertThat(result).isEqualTo("hello");
    }
}
```

#### DAO (Custom Database Access Implementation)

**Test approach:** Unit test with mocked persistence abstraction (e.g., `EntityManager`, `JdbcTemplate`).

**Mandatory constraints:**

- Use `@ExtendWith(MockitoExtension.class)` + `@Mock` for persistence mechanism
- Declare the DAO field with **interface type** (if applicable), instantiate with **impl + mocked constructor deps**
- Mock the persistence mechanism (EntityManager for JPA, JdbcTemplate for JDBC)
- Test SQL mapping, query parameter binding, and result set mapping
- Verify correct DAO method calls on the mocked abstraction
- **Do NOT** test the DAO with a real database (that's integration-level)

**Example test pattern (JPA):**

```java

@ExtendWith(MockitoExtension.class)
class UserDaoTest {
    @Mock
    private EntityManager entityManager;

    // Field typed as interface (if DAO interface exists), instantiated with impl + mocked deps
    private UserDao userDao = new UserDaoImpl(entityManager);

    @Test
    void shouldReturnUserWhenNamedQueryExecutes() {
        // Arrange
        var query = mock(TypedQuery.class);
        when(entityManager.createNamedQuery("User.findByName", User.class))
                .thenReturn(query);
        when(query.setParameter("name", "John"))
                .thenReturn(query);
        when(query.getSingleResult()).thenReturn(expectedUser);

        // Act
        User result = userDao.findByName("John");

        // Assert
        assertThat(result).isEqualTo(expectedUser);
        verify(entityManager).createNamedQuery("User.findByName", User.class);
    }
}
```

#### Spring Repository Interface (JpaRepository, CrudRepository, etc.)

**Test approach:** **NOT tested at unit level**. Spring's repository implementations are tested by Spring itself.

**Why no custom unit tests:**

- `@Repository` interfaces extending `JpaRepository`, `CrudRepository`, etc. are Spring's responsibility
- Custom methods **without implementation** are generated by Spring Data
- Custom **implemented** methods on repository should be tested as part of integration tests with `@DataJpaTest` or
  `@SpringBootTest`

**When to test repository-like behavior:**

- Test the **DAO** class (custom DB access implementation) that handles the actual query logic
- Test the **Service** class that orchestrates repository calls with business logic

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

Check `pom.xml` (or `build.gradle`) for the assertion library before generating tests:

| Condition                                                   | Library to use                             |
|-------------------------------------------------------------|--------------------------------------------|
| `assertj-core` **or** `spring-boot-starter-test` is present | **AssertJ** (preferred)                    |
| Neither is present                                          | **JUnit 5 built-in** assertions (fallback) |

**When AssertJ is available:**

- `assertThat(result).isEqualTo(expected)`
- `assertThat(result).isNotNull()`
- `assertThat(list).containsExactly(...)`
- `assertThatThrownBy(() -> ...).isInstanceOf(X.class).hasMessage("...")`
- Never use `assertTrue(result == x)` — always use fluent assertions

**When AssertJ is NOT available (JUnit 5 fallback):**

- `assertEquals(expected, actual)`
- `assertNotNull(result)`
- `assertThrows(X.class, () -> service.call(...))`
- `assertAll(...)` to group multiple assertions without short-circuiting

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