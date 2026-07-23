# GitHub Copilot Configuration

This directory contains the complete GitHub Copilot agent and skill configuration for code review and TDD test
generation.

## 📁 Directory Structure

```
.github/
├── README.md                           # This file
├── token_optimization_summary.md       # Implementation documentation
├── agents/
│   ├── code-review.agent.md            # Code review agent
│   ├── code-review.agent.md.template   # Code review agent template (for installer)
│   ├── tdd-generator.agent.md          # TDD test generator agent
│   └── tdd-generator.agent.md.template # TDD generator template (for installer)
├── config/
│   ├── copilot-config.yml              # Project configuration
│   └── copilot-config.template.yml     # Config template (for installer)
├── docs/
│   └── USAGE.md.template               # Usage guide template (for installer)
├── instructions/
│   ├── copilot-instructions.md         # Coding instructions for GitHub Copilot
│   └── copilot-instructions.md.template # Instructions template (for installer)
├── patterns/
│   ├── test-patterns.yml               # Test generation patterns (shared)
│   └── review-patterns.yml             # Code review patterns (shared)
└── skills/
    ├── code-review/
    │   ├── code-review.skill.md        # Code review skill
    │   └── code-review.skill.md.template # Skill template (for installer)
    └── write-failing-test/
        ├── write-failing-test.skill.md  # Test generation skill
        └── write-failing-test.skill.md.template # Skill template (for installer)
```

## 🎯 Purpose

This GitHub Copilot configuration provides:

1. **TDD Test Generation** - Generate failing unit tests (RED phase)
2. **Code Review** - Automated code reviews with SOLID, DRY, KISS, security checks
3. **Token Optimization** - 50-60% reduction in AI token usage
4. **Pattern-Based Generation** - Consistent, repeatable outputs

## 🚀 Quick Start

### Using TDD Generator Agent

In GitHub Copilot Chat, type:

```
@workspace Use the tdd-generator agent to create tests for UserService
```

The agent will:

- Read cached configuration from `.github/config/copilot-config.yml`
- Load test patterns from `.github/patterns/test-patterns.yml`
- Generate failing unit tests following TDD best practices
- Provide mutation testing configuration

### Using Code Review Agent

In GitHub Copilot Chat, type:

```
@workspace Use the code-review agent to review my changes
```

The agent will:

- Read cached configuration from `.github/config/copilot-config.yml`
- Load review patterns from `.github/patterns/review-patterns.yml`
- Analyze modified files from git status
- Generate comprehensive review report

## 📊 Implementation Statistics

| Metric                     | Value     |
|----------------------------|-----------|
| Total files                | 8         |
| Configuration lines        | 46        |
| Instruction lines          | 67        |
| Pattern lines (shared)     | 625       |
| Agent lines                | 647       |
| Skill lines                | 1,112     |
| **Total lines**            | **3,004** |
| Token reduction (1st call) | 32%       |
| Token reduction (cached)   | 61%       |

## 🤖 GitHub Copilot Agent Usage

GitHub Copilot supports custom agents through the `@workspace` context. Agents are automatically discovered from the
`.github/agents/` directory when you invoke them in chat.

### Basic Invocation Pattern

```
@workspace <describe what you want the agent to do>
```

GitHub Copilot will:

1. Scan `.github/agents/` for matching agent definitions
2. Load the relevant agent's instructions and skills
3. Execute the agent's workflow
4. Return structured output

### Example Prompts

**TDD Generator:**

```
@workspace Generate failing tests for UserService with the following:
Feature: Create and retrieve users from database
SUT Type: service
Dependencies: UserRepository
```

**Code Review:**

```
@workspace Review the UserServiceImpl.java file for SOLID violations and testability issues
```

### Tips for GitHub Copilot

| Tip                     | Detail                                                            |
|-------------------------|-------------------------------------------------------------------|
| **Use @workspace**      | Always prefix agent requests with `@workspace` for proper context |
| **Be specific**         | Provide clear feature descriptions and class names                |
| **Check agent files**   | Verify agents exist at `.github/agents/*.agent.md`                |
| **Session persistence** | GitHub Copilot maintains context within a single chat session     |

---

## 🔄 Synchronization

### Pattern File Sync

Pattern files are tool-agnostic and shared between GitHub Copilot and GitLab Duo. To keep them synchronized:

```bash
# Run from project root
./.gitlab/sync-patterns.sh
```

This script copies:

- `.github/patterns/test-patterns.yml` → `.gitlab/patterns/test-patterns.yml`
- `.github/patterns/review-patterns.yml` → `.gitlab/patterns/review-patterns.yml`

### When to Sync

Run the sync script after:

- Updating test patterns in `.github/patterns/test-patterns.yml`
- Updating review patterns in `.github/patterns/review-patterns.yml`
- Adding new pattern categories
- Modifying detection rules

### Manual Updates Required

The following files need manual updates (not synced automatically):

- `config/copilot-config.yml` - Project-specific settings
- Agent files - Logic changes (with path updates)
- Skill files - Logic changes (with path updates)

## 📝 Configuration

### Project Configuration (`config/copilot-config.yml`)

Key settings:

- **JDK Version:** 17
- **Spring Boot:** 3.5.11
- **Base Package:** `com.hcltech.demo.coding.agent`
- **Testing Framework:** JUnit 5 + Mockito
- **Mutation Tool:** PIT

To update:

1. Edit `.github/config/copilot-config.yml`
2. Restart GitHub Copilot or reload VS Code window to refresh cache

### Token Economy Settings

All agents follow these rules:

1. Cache config files (read once per session)
2. Never scan entire repository
3. No semantic_search unless explicitly requested
4. No dependency chain traversal
5. Progressive disclosure (required fields only)
6. Maximum 3 context file reads
7. Use YAML patterns (not prose)
8. Session-based caching

## 🧪 Testing

### Verify Installation

```bash
# Check all files exist
ls -la .github/agents/
ls -la .github/skills/*/
# Verify pattern files are identical
diff .github/patterns/test-patterns.yml .gitlab/patterns/test-patterns.yml
diff .github/patterns/review-patterns.yml .gitlab/patterns/review-patterns.yml
# Count total lines
wc -l .github/**/*.{yml,md}
```

### Test Agents

**TDD Generator:**

```
@workspace Generate tests for UserService
Feature: Create and retrieve users from database
```

**Code Review:**

```
@workspace Review my recent changes
```

## 📚 Documentation

- **token_optimization_summary.md** - Complete implementation details
- **instructions/copilot-instructions.md** - Coding standards and TDD rules
- **config/copilot-config.yml** - Project configuration reference

## 🔧 Maintenance

### Adding New Patterns

1. Add pattern to `.github/patterns/test-patterns.yml` or `.github/patterns/review-patterns.yml`
2. Run sync script: `./.gitlab/sync-patterns.sh`
3. Test with both GitHub Copilot and GitLab Duo

### Updating Agent Logic

1. Update `.github/agents/<agent-name>.agent.md`
2. Manually replicate changes to `.gitlab/agents/<agent-name>.agent.md`
3. Update path references: `.github/` → `.gitlab/`, `copilot-config.yml` → `duo-config.yml`

### Updating Skill Logic

1. Update `.github/skills/<skill-name>/<skill-name>.skill.md`
2. Manually replicate changes to `.gitlab/skills/<skill-name>/<skill-name>.skill.md`
3. Update path references: `.github/` → `.gitlab/`, `copilot-config.yml` → `duo-config.yml`

## 🆚 GitHub Copilot vs GitLab Duo

### Similarities

- Identical pattern files
- Same token optimization rules
- Same output quality
- Same test structures
- Same review criteria

### Differences

- Directory: `.github/` vs `.gitlab/`
- Config file: `config/copilot-config.yml` vs `config/duo-config.yml`
- Instructions: `instructions/copilot-instructions.md` vs `instructions/duo-instructions.md`
- Invocation: `@workspace` vs manual discovery in browser
- All path references updated

## 💡 Tips

1. **Cache Warming** - First agent invocation in a session loads config (slower), subsequent calls use cache (faster)
2. **Pattern Updates** - Always sync patterns to both directories
3. **Window Reload** - Reload VS Code window to refresh configuration
4. **Progressive Disclosure** - Type 'skip' to accept inferred defaults, 'configure' for full options
5. **Token Savings** - Avoid 'deep review' unless necessary (uses more tokens)

## 🐛 Troubleshooting

### Pattern Files Out of Sync

```bash
# Re-sync patterns
./.gitlab/sync-patterns.sh
# Verify sync
diff .github/patterns/test-patterns.yml .gitlab/patterns/test-patterns.yml
```

### Agent Not Found

```bash
# Check agent files exist
ls -la .github/agents/
# Verify correct naming
cat .github/agents/tdd-generator.agent.md | head -3
# Reload VS Code window
# Command Palette > Developer: Reload Window
```

### Configuration Not Loading

```bash
# Verify config file
cat .github/config/copilot-config.yml
# Reload VS Code window
# (Configuration is cached per session)
```

## 📖 Additional Resources

- [Token Optimization Summary](./token_optimization_summary.md)
- [Test Patterns Reference](./patterns/test-patterns.yml)
- [Review Patterns Reference](./patterns/review-patterns.yml)
- [Copilot Instructions](./instructions/copilot-instructions.md)
- [Copilot Configuration](./config/copilot-config.yml)
- [GitLab Duo Configuration](../.gitlab/README.md) - Parallel setup for GitLab Duo

## ✅ Checklist

After installation, verify:

- [ ] Directory structure created (agents/, config/, docs/, instructions/, patterns/, skills/)
- [ ] All agent, skill, and template files present
- [ ] Pattern files synced and identical
- [ ] Sync script executable (`chmod +x .gitlab/sync-patterns.sh`)
- [ ] config/copilot-config.yml has correct project values
- [ ] TDD generator agent works with `@workspace`
- [ ] Code review agent works with `@workspace`
- [ ] Token economy rules active

## 📞 Support

For questions or issues:

1. Check TOKEN_OPTIMIZATION_SUMMARY.md for detailed information
2. Verify pattern file synchronization
3. Review agent/skill file path references
4. Ensure GitHub Copilot extension can access .github/ directory
5. Try reloading VS Code window to refresh configuration

---
**Last Updated:** July 3, 2026  
**Version:** 2.0.0  
**Status:** ✅ Production Ready
