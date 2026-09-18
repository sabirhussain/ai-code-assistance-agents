---
name: nw-project-analyzer
description: Manifest-file detection catalog, framework/datastore/CI signature tables, and tech-stack.yaml output schema for automated technology-stack scanning
user-invocable: false
disable-model-invocation: true
---

# Project Analyzer Detection Catalog

Reference tables for detecting a repository's technology stack from manifest and config files. Every finding must cite
the file that evidenced it — no signature match, no entry.

## 1. Manifest Files by Ecosystem

| Ecosystem     | Manifest(s)                                                 | Language              | Package Manager / Build Tool                                               | Language Version Signal                                                                                                                                        |
|---------------|-------------------------------------------------------------|-----------------------|----------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Java (Maven)  | `pom.xml`                                                   | Java/Kotlin           | Maven                                                                      | `<properties><java.version>`, `<maven.compiler.release>`/`<maven.compiler.source>`, or the parent `spring-boot-starter-parent` version's default Java baseline |
| Java (Gradle) | `build.gradle`, `build.gradle.kts`, `settings.gradle*`      | Java/Kotlin           | Gradle                                                                     | `sourceCompatibility`/`targetCompatibility`, or `java { toolchain { languageVersion } }`                                                                       |
| Node.js       | `package.json`                                              | JavaScript/TypeScript | npm (`package-lock.json`) \| yarn (`yarn.lock`) \| pnpm (`pnpm-lock.yaml`) | `engines.node`                                                                                                                                                 |
| Python        | `requirements.txt`, `pyproject.toml`, `Pipfile`, `setup.py` | Python                | pip \| poetry (`poetry.lock`) \| pipenv (`Pipfile.lock`)                   | `requires-python`/`python_requires` (pyproject.toml, setup.py), `python_version` (Pipfile)                                                                     |
| Rust          | `Cargo.toml`                                                | Rust                  | cargo                                                                      | `rust-version` or `edition`                                                                                                                                    |
| Go            | `go.mod`                                                    | Go                    | go modules                                                                 | the `go` directive (e.g. `go 1.22`)                                                                                                                            |
| Ruby          | `Gemfile`                                                   | Ruby                  | bundler                                                                    | a `ruby` pin in Gemfile, if present                                                                                                                            |
| .NET          | `*.csproj`, `*.sln`                                         | C#/.NET               | NuGet                                                                      | `<TargetFramework>`/`<TargetFrameworks>`                                                                                                                       |
| PHP           | `composer.json`                                             | PHP                   | composer                                                                   | `require.php`                                                                                                                                                  |

Glob for these first. A repo may match multiple rows (polyglot monorepo) — record each matched row as its own separate
stack entry. Record a `language_version` field only when the version signal is actually present in the manifest; omit
the field rather than guess.

## 2. Framework Signature Table

Search dependency blocks of the matched manifest (Grep, not full parse) for these substrings. Capture the framework's
version from the same location: the dependency's own `<version>`/version string, or — for Maven artifacts under
`spring-boot-starter-parent` (or another BOM-managed parent) — the parent's `<version>`.

| Framework    | Signature              | Found In                         |
|--------------|------------------------|----------------------------------|
| Spring Boot  | `spring-boot-starter`  | pom.xml, build.gradle            |
| Quarkus      | `quarkus-`             | pom.xml, build.gradle            |
| React        | `"react"` dependency   | package.json                     |
| Vue          | `"vue"` dependency     | package.json                     |
| Angular      | `"@angular/core"`      | package.json                     |
| Express      | `"express"` dependency | package.json                     |
| Next.js      | `"next"` dependency    | package.json                     |
| Django       | `django`               | requirements.txt, pyproject.toml |
| Flask        | `flask`                | requirements.txt, pyproject.toml |
| FastAPI      | `fastapi`              | requirements.txt, pyproject.toml |
| ASP.NET Core | `Microsoft.AspNetCore` | *.csproj                         |
| Rails        | `rails`                | Gemfile                          |

If a manifest is found but no signature matches, record the language/build-tool entry with `frameworks: []` and add it
to `unresolved`, leaving the framework choice open rather than guessed. Record a framework's `version` field only when
it is actually resolvable from the manifest; omit the field rather than guess.

## 3. Testing Framework Signature Table

Search the same dependency blocks for test-scoped signatures. Group results per stack entry into up to three roles:
`framework` (the test runner), `mocking` (mock library), `assertions` (assertion library). Populate only the roles that
actually matched; omit a role entirely rather than guess, and omit the whole `testing` block for a stack when none
matched.

| Ecosystem | Role       | Test Library | Signature                                                                             | Found In                         |
|-----------|------------|--------------|---------------------------------------------------------------------------------------|----------------------------------|
| Java      | framework  | JUnit 5      | `junit-jupiter`, or `spring-boot-starter-test` (Spring Boot 2.2+ defaults to JUnit 5) | pom.xml, build.gradle            |
| Java      | framework  | JUnit 4      | `junit:junit` (4.x)                                                                   | pom.xml, build.gradle            |
| Java      | mocking    | Mockito      | `mockito-core`, `mockito-junit-jupiter`                                               | pom.xml, build.gradle            |
| Java      | assertions | AssertJ      | `assertj-core`                                                                        | pom.xml, build.gradle            |
| Node.js   | framework  | Jest         | `"jest"` dependency                                                                   | package.json                     |
| Node.js   | framework  | Mocha        | `"mocha"` dependency                                                                  | package.json                     |
| Node.js   | mocking    | Sinon        | `"sinon"` dependency                                                                  | package.json                     |
| Node.js   | assertions | Chai         | `"chai"` dependency                                                                   | package.json                     |
| Python    | framework  | pytest       | `pytest`                                                                              | requirements.txt, pyproject.toml |
| Python    | mocking    | pytest-mock  | `pytest-mock`                                                                         | requirements.txt, pyproject.toml |
| Ruby      | framework  | RSpec        | `rspec`                                                                               | Gemfile                          |
| .NET      | framework  | xUnit        | `xunit`                                                                               | *.csproj                         |
| .NET      | framework  | NUnit        | `NUnit`                                                                               | *.csproj                         |

## 4. Datastore / Infra Signature Table

| Technology     | Signature                                            | Found In                                              |
|----------------|------------------------------------------------------|-------------------------------------------------------|
| Redis          | `redis` image/service, `spring.redis.*`, `redis://`  | docker-compose*.yml, application.properties/yml, .env |
| PostgreSQL     | `postgres` image, `jdbc:postgresql`, `postgresql://` | docker-compose*.yml, application.properties/yml       |
| MySQL/MariaDB  | `mysql`/`mariadb` image, `jdbc:mysql`                | docker-compose*.yml, application.properties/yml       |
| MongoDB        | `mongo` image, `mongodb://`                          | docker-compose*.yml, application.properties/yml       |
| Kafka          | `kafka` image, `spring.kafka.*`                      | docker-compose*.yml, application.properties/yml       |
| RabbitMQ       | `rabbitmq` image                                     | docker-compose*.yml                                   |
| Elasticsearch  | `elasticsearch` image                                | docker-compose*.yml                                   |
| Docker         | `Dockerfile` present                                 | repo root or module dirs                              |
| Docker Compose | `docker-compose*.yml` present                        | repo root                                             |
| Kubernetes     | `kind: Deployment\|StatefulSet\|Service`             | *.yaml under k8s/, manifests/, deploy/                |

## 5. CI Config Detection

| Signature File            | CI Platform         |
|---------------------------|---------------------|
| `.github/workflows/*.yml` | GitHub Actions      |
| `.gitlab-ci.yml`          | GitLab CI           |
| `Jenkinsfile`             | Jenkins             |
| `.circleci/config.yml`    | CircleCI            |
| `azure-pipelines.yml`     | Azure Pipelines     |
| `bitbucket-pipelines.yml` | Bitbucket Pipelines |

## 6. Confidence Tagging

- `confirmed` — signature matched inside a manifest/config file, file path cited as evidence.
- `inferred` — pattern suggests a technology but no direct manifest signature (e.g., a `redis-cli` mention in a README,
  a folder named `redis-cache` with no docker-compose entry). Use sparingly and always label.
- Every `confirmed` entry in `datastores`, `infra`, `ci`, and `unresolved` requires an `evidence` file path. `stacks`
  entries (language/build_tool/frameworks/testing) do not carry a separate `evidence` field — the manifest that produced
  them is unambiguous from the ecosystem itself (e.g. a Java stack entry always comes from `pom.xml` or
  `build.gradle*`), so citing it again is redundant.

## 7. Output Location

Write the output file to `.nwave/tech-stack.yaml`, relative to repo root, creating the `.nwave/` directory first if
needed. After writing, ensure `.gitignore` (repo root) contains a `.nwave/` entry — append it if the file exists and
lacks the entry; when no `.gitignore` exists, leave the repo as-is (creating one is out of scope).

## 8. tech-stack.yaml Output Schema

```yaml
repository: {repo-name}
generated_by: nw-project-analyzer
generated_at: {ISO-8601 timestamp}
stacks:
  - language: Java
    language_version: "17"
    build_tool: Maven
    package_manager: Maven
    frameworks:
      - name: Spring Boot
        version: "3.5.11"
    testing:
      framework: junit-5
      mocking: mockito
      assertions: assertj
datastores:
  - name: Redis
    confidence: confirmed
    evidence: [docker-compose.yml, src/main/resources/application.yml]
infra:
  - name: Docker
    confidence: confirmed
    evidence: Dockerfile
  - name: Docker Compose
    confidence: confirmed
    evidence: docker-compose.yml
ci:
  - platform: GitHub Actions
    evidence: .github/workflows/build.yml
unresolved:
  - note: "requirements.txt found, no framework signature matched"
    evidence: requirements.txt
```

Field rules: `stacks` is always an array (supports polyglot repos). `language_version` and each framework's `version`
are included only when the manifest actually states them — omit rather than guess. `testing` is included per stack only
when at least one role (`framework`/`mocking`/`assertions`) matched; omit roles that did not match, and omit the whole
block when none did. `datastores`, `infra`, `ci` are arrays, present with an empty `[]` when nothing detected.
`unresolved` captures manifests found with no confident framework match, keeping the output honest about detection gaps.
