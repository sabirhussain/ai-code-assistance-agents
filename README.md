# GitHub Copilot Custom Agents — Multi-Stack

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub release](https://img.shields.io/github/release/sabirhussain/ai-code-assistance-agents.svg)](https://github.com/sabirhussain/ai-code-assistance-agents/releases)

> **Supercharge your development with custom GitHub Copilot agents — Java/Spring Boot, Node.js, Python, Go, and more**

This repository provides production-ready, token-optimized custom agents for GitHub Copilot CLI that specialize in
Test-Driven Development (TDD) and code review. Agents adapt to your repo's tech stack via a lightweight local config.

## 🚀 Quick Start

**Step 1** — Install agents system-wide (once per machine):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sabirhussain/ai-code-assistance-agents/main/github-agent-install.sh)
```

**Step 2** — Set up config for your repo (once per repo):

```bash
# Run from inside your project repo
gh copilot agent repo-config
```

The `repo-config` agent reads your project files, detects the stack, and generates `.github/copilot-config.yml`.

## 🤖 Available Agents

### 🏗️ Repo Config (`repo-config`) — *Run first in each new repo*

Generates `.github/copilot-config.yml` for the current git repo. Auto-detects your tech stack by reading project
files, confirms values with you, writes the config, and updates `.gitignore`.

**Usage**: `gh copilot agent repo-config`

**Auto-detects**:

| File found | Detected stack |
|---|---|
| `pom.xml` | Java / Spring Boot (Maven) |
| `build.gradle` / `build.gradle.kts` | Java / Spring Boot (Gradle) |
| `package.json` | Node.js / TypeScript |
| `pyproject.toml` / `requirements.txt` | Python |
| `go.mod` | Go |
| *(none of the above)* | Generic |

The generated config is **gitignored** — each developer runs this once per repo. Re-run at any time to update.

### 🧪 TDD Generator (`tdd-generator`)

Generates comprehensive failing unit tests following TDD principles. Produces JUnit 5 + Mockito tests with mutation
testing configuration.

**Usage**: `gh copilot agent tdd-generator`

**Features**:

- ✅ RED phase only (generates failing tests, never implementation)
- ✅ AAA pattern (Arrange-Act-Assert)
- ✅ Automatic dependency inference
- ✅ PIT mutation testing integration
- ✅ Token-optimized (minimal context reads)

### 🔍 Code Review Agent (`spring-boot-peer-review`)

Performs intelligent code reviews focused on architecture, security, and testability for Java/Spring Boot code.

**Usage**: `gh copilot agent spring-boot-peer-review`

**Review Priorities**:

1. 🔴 **Security** - Credentials, secrets, vulnerabilities
2. 🟠 **Architectural Risks** - SOLID violations, DI anti-patterns
3. 🟡 **Exception Handling** - Swallowed exceptions, missing `@ControllerAdvice`, `ProblemDetail` (Spring Boot 3.x)
4. 🟡 **Spring Boot Non-Negotiables** - OSIV, `@Transactional` placement, `@Valid`, Actuator exposure
5. 🟢 **Testability** - Hidden dependencies, static calls; prefer testability in complex trade-offs
6. 🟢 **Maintainability** - DRY, KISS, complexity, method size
7. 🔵 **Modernization** - JDK improvements, best practices (version-aware)
8. ⚪ **Backward Compatibility** *(opt-in)* - API breaks, REST contract changes, DTO/serialization, config renames, crypto algorithm changes — say *"check backward compatibility"* or *"breaking changes"*

## 📦 What Gets Installed

```
~/.copilot/
├── agents/
│   ├── tdd-generator.agent.md
│   ├── spring-boot-peer-review.agent.md
│   └── repo-config.agent.md
├── skills/
│   ├── write-failing-test/
│   ├── code-review/
│   └── backward-compat/          ← backward compatibility audit skill
├── config/
│   └── copilot-config.yml          ← global default (used when no local config exists)
├── patterns/
│   ├── test-patterns.yml
│   └── review-patterns.yml
├── instructions/
│   └── copilot-instructions.md
└── USAGE.md
```

## 💡 Usage Examples

### Accessing Custom Agents

Select your custom agents from the Agent dropdown in GitHub Copilot CLI:

<img src="images/how-to-use-agent.png" alt="How to use custom agents" width="600px"/>

### Generate Tests for a New Feature

```bash
$ gh copilot agent tdd-generator

You: Generate tests for PaymentService that validates amounts,
     processes credit cards, and handles failures with retry logic

Agent: [Generates PaymentServiceTest.java with comprehensive test cases]
```

### Review Changed Files Before Commit

```bash
$ git status
  Modified: src/main/java/com/example/UserService.java

$ gh copilot agent spring-boot-peer-review

Agent: [Reviews file and reports security, architecture, and testability issues]
```

### Deep Architectural Review

```bash
$ gh copilot agent spring-boot-peer-review "deep review src/main/java/com/example/auth/"

Agent: [Performs cross-file analysis with dependency checking]
```

### Backward Compatibility Audit

```bash
$ gh copilot agent spring-boot-peer-review

You: Check backward compatibility of my changes

Agent: [Audits public API, REST contracts, DTOs, config properties, Spring beans,
        JPA mappings, and cryptographic configurations for breaking changes.
        Produces a ⚠️ Backward Compatibility Warnings section, or ✅ All Clear.]
```

## ⚙️ Configuration

### How Config Resolution Works

Agents resolve config in priority order:

1. **`.github/copilot-config.yml`** — repo-local, gitignored, generated by `repo-config` agent
2. **`~/.copilot/config/copilot-config.yml`** — global default, set during install

If neither exists, agents stop and prompt: *"Run `gh copilot agent repo-config` to generate one."*

### Per-Repo Config (Recommended)

Run the `repo-config` agent once in each repo where the tech stack differs from your global default:

```bash
cd your-project/
gh copilot agent repo-config
```

The agent reads your project files and generates `.github/copilot-config.yml`:

```yaml
# .github/copilot-config.yml  — gitignored, generated by repo-config agent

project:
  language: Java
  lang_version: 21
  build_tool: Maven

framework:
  spring_boot_version: 3.5.2

package:
  base: com.example.payments
  test_path: src/test/java/com/example/payments
  main_path: src/main/java/com/example/payments

testing:
  framework: JUnit 5 + Mockito
  mutation_tool: PIT
  nested_test: true
  aaa_comments: true
```

This file is automatically added to `.gitignore` — each developer runs `repo-config` once per repo.

### Global Config (Fallback)

The global config at `~/.copilot/config/copilot-config.yml` is used when no local config exists.
Customize it after install for your most common stack:

```bash
# Edit global config
nano ~/.copilot/config/copilot-config.yml
```

## 🔧 Installation Options

### Interactive Install (default)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sabirhussain/ai-code-assistance-agents/main/github-agent-install.sh)
```

Prompts for configuration values with sensible defaults.

### Non-Interactive Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sabirhussain/ai-code-assistance-agents/main/github-agent-install.sh) -y
```

Uses all defaults for quick personal setup.

### Enterprise/Team Setup (Recommended for CI/CD)

For company-wide or team deployments:

1. **Fork this repository** to your organization
2. **Customize templates** in `.github/` directory:
    - Update `copilot-config.template.yml` with your company defaults
    - Modify `copilot-instructions.md.template` for your coding standards
    - Adjust pattern files for your tech stack
3. **Deploy to team**:
   ```bash
   bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_ORG/ai-code-assistance-agents/main/github-agent-install.sh) -y
   ```

This ensures consistent configuration across your organization.

### Local Testing Mode (for developers)

```bash
# Run installer in local mode
./github-agent-install.sh --local
```

Tests installer with local files before pushing to GitHub. See [LOCAL_TESTING.md](local_testing.md) for details.

### Show Help

```bash
./github-agent-install.sh -h
```

## 🛡️ Safety Features

- ✅ **Automatic Backup**: Existing installations backed up to `~/.copilot.backup-TIMESTAMP/`
- ✅ **Idempotent**: Can run multiple times safely
- ✅ **Network Validation**: Tests GitHub connectivity before starting
- ✅ **Permission Checks**: Validates write permissions upfront
- ✅ **Graceful Failures**: Clear error messages with actionable steps

## 📚 Documentation

After installation, comprehensive documentation is available at `~/.copilot/USAGE.md`:

```bash
cat ~/.copilot/USAGE.md
```

**Includes**:

- Detailed agent descriptions and use cases
- Configuration guide with examples
- Troubleshooting common issues
- Update and uninstall instructions
- Quick reference card

## 🔄 Updating

Re-run the installer to update to the latest version:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sabirhussain/ai-code-assistance-agents/main/github-agent-install.sh)
```

Your existing installation will be backed up automatically.

## 🗑️ Uninstalling

### Safe Uninstall (Recommended)

Removes only files installed by this project, preserves other custom agents/skills:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sabirhussain/ai-code-assistance-agents/main/uninstall-github-agent.sh)
```

Or download and run locally:

```bash
curl -fsSL https://raw.githubusercontent.com/sabirhussain/ai-code-assistance-agents/main/uninstall-github-agent.sh -o uninstall-github-agent.sh
chmod +x uninstall-github-agent.sh
./uninstall-github-agent.sh
```

**What gets removed**:

- `tdd-generator` and `spring-boot-peer-review` agents
- Associated skills and configuration files
- Pattern files and instructions
- USAGE.md guide

**What's preserved**:

- Directory structure (`agents/`, `skills/`, etc.)
- Other custom agents or skills you may have
- Your custom configurations

### Restore From Backup

```bash
ls -d ~/.copilot.backup-*
cp -R ~/.copilot.backup-20260722-143000 ~/.copilot
```

## 🎯 Key Features

### Token Economy Optimized

All agents implement aggressive token optimization:

- Configuration values cached for session duration
- Progressive disclosure (ask only required fields)
- Maximum 3 context file reads unless explicitly needed
- No semantic search unless user explicitly requests it

### TDD-First Philosophy

The TDD Generator strictly follows RED phase only:

- Never creates implementation classes
- Never modifies build files (provides snippets as reference)
- Tests fail because implementation doesn't exist (this is correct!)

### Intelligent Code Review

The Code Review agent uses a priority-based approach:

- **Targeted Review** (default): Only review explicitly requested or changed files
- **Deep Review** (on request): Analyze dependencies and architectural impact
- Never reports style issues or formatting nitpicks
- Only surfaces genuinely important problems

## 📋 Requirements

- **GitHub Copilot CLI** installed and configured
- **curl** for downloading installer
- **Bash** (macOS, Linux, WSL, Git Bash)
- Internet connection to GitHub

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/sabirhussain/ai-code-assistance-agents.git
   cd ai-code-assistance-agents
   ```

2. Test installer locally:
   ```bash
   bash github-agent-install.sh
   ```

3. Make changes to templates in `.github/`

4. Test with a fresh install

## 🐛 Troubleshooting

### Agent Not Found

```bash
# Verify installation
ls ~/.copilot/agents/

# Re-run installer if needed
bash <(curl -fsSL https://raw.githubusercontent.com/sabirhussain/ai-code-assistance-agents/main/github-agent-install.sh)
```

### Configuration Not Applied

```bash
# Check for template placeholders
grep -r "{{" ~/.copilot/

# If found, re-run installer
bash <(curl -fsSL https://raw.githubusercontent.com/sabirhussain/ai-code-assistance-agents/main/github-agent-install.sh) -y
```

### Network Errors

```bash
# Test GitHub connectivity
curl -I https://github.com

# Try with timeout
timeout 300 bash <(curl -fsSL https://raw.githubusercontent.com/sabirhussain/ai-code-assistance-agents/main/github-agent-install.sh)
```

See `~/.copilot/USAGE.md` for comprehensive troubleshooting guide.

## 📝 License

MIT License - see [LICENSE](LICENSE) for details.

## 🌟 Show Your Support

If you find these agents useful, please consider:

- ⭐ Starring this repository
- 🐛 Reporting issues you encounter
- 💡 Suggesting new features or improvements
- 🤝 Contributing code or documentation

## 📞 Support

- **Issues**: https://github.com/sabirhussain/ai-code-assistance-agents/issues
- **Discussions**: https://github.com/sabirhussain/ai-code-assistance-agents/discussions

---

**Made with ❤️ for the developer community**

*Enhance your development workflow with AI-powered TDD and code review — across any tech stack!*
