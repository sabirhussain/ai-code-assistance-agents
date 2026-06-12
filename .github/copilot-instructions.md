# Copilot Instructions

> **Project configuration is defined in `.github/copilot-config.yml`.**
> Read that file to determine the active JDK, Spring Boot version, Spring AI version,
> AI model, base package, and testing framework for this project.

## How to Read Project Config

When answering any question or generating any code for this project:

1. Load values from `.github/copilot-config.yml`
2. Apply them to all generated code, imports, and configuration snippets
3. Never hardcode versions — always use values from the config file

## Coding Standards (Always Apply)

- Use Lombok (`@RequiredArgsConstructor`, `@Slf4j`, etc.)
- Use constructor injection — never field injection, never `@Autowired` on fields
- All services annotated with `@Service`
- All helpers/utilities annotated with `@Component`
- Use the `base` package from config for all generated classes

## TDD Rules (ALWAYS follow — regardless of project config)

1. YOU ONLY DO RED — generate failing tests only, never implementation
2. Tests MUST reference classes/methods that do not exist yet — this is correct and expected
3. Never create Service, Repository, Controller, or any implementation class
4. Never create interface definitions or entity/model classes
5. Never modify `pom.xml`, `build.gradle`, or any build file — only provide config snippets as reference
6. Test class naming: `<ClassName>Test.java`
7. Test method naming: `should<ExpectedBehavior>When<Condition>()`
8. Use the test framework specified in `copilot-config.yml → testing.framework`
9. Use Mockito for all dependencies — never use real implementations
10. Follow AAA pattern: Arrange, Act, Assert
11. Always provide mutation testing snippet (tool from `copilot-config.yml → testing.mutation_tool`) alongside tests —
    as reference only if not present in the project already.

## AI Model Usage (Spring AI projects)

- Use the `ai_provider` and `ai_model` from config for all Spring AI code examples
- Use `spring-ai-starter-model-openai` for OpenAI-compatible providers (Groq, OpenAI)
- Use `spring-ai-starter-model-anthropic` for Anthropic
- Use `spring-ai-starter-model-ollama` for Ollama

## Language-Specific Test Framework Mapping

| Language      | Framework (from config) |
|---------------|-------------------------|
| Java          | JUnit 5 + Mockito       |
| JavaScript/TS | Jest or Vitest          |
| Python        | PyTest                  |
| C#            | xUnit or NUnit          |

Always match the test framework to the language — override only if `testing.framework` is explicitly set in config.