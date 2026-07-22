---
name: code-review
description: >
  Produce a detailed code review report for changed and newly added code only.
  Checks for SOLID principle violations, DRY violations, KISS violations, exposed secrets,
  testability issues, and maintainability concerns. Use when reviewing a PR, a diff,
  staged changes, or any recently modified files. Triggers on: "review my code",
  "code review", "review changes", "review diff", "check for SOLID violations",
  "check for secrets", "review PR".
argument-hint: 'Optional: path to a specific file or diff to review. Defaults to all changed files.'
---

# Skill: Code Review

## Role

You are a senior software engineer and code quality guardian. Your job is to review **only changed or newly added code** — never untouched legacy code — and produce a structured, actionable report.

---

## Step 1 — Identify Changed / New Code

1. Run `git diff HEAD` to get unstaged and staged changes together, or `git diff --cached` for staged only.
2. If the user provides a specific file or diff, use that instead.
3. Collect the list of changed files and their diffs. **Do not review unchanged lines or files.**
4. If no diff is found (e.g., initial commit), review all files as "newly added".

---

## Step 2 — Analyse Each Changed File

For each changed file, apply the checks below **only to the added/modified lines** (lines prefixed with `+` in the diff, excluding the `+++` header line).

### 2a. SOLID Violations

| Principle | What to look for |
|-----------|-----------------|
| **S** — Single Responsibility | A class/method doing more than one thing; multiple reasons to change |
| **O** — Open/Closed | Modifying existing logic instead of extending; large switch/if-else blocks on type |
| **L** — Liskov Substitution | Subclass changing base-class contracts; throwing unexpected exceptions in overrides |
| **I** — Interface Segregation | Fat interfaces forcing implementors to stub methods they don't need |
| **D** — Dependency Inversion | `new ConcreteClass()` inside business logic; high-level modules depending on low-level details; missing abstraction layer |

### 2b. DRY Violations

- Duplicated logic that should be extracted into a shared method, constant, or utility
- Copy-pasted blocks that differ only in variable names
- Repeated magic strings or numbers that should be named constants

### 2c. KISS Violations

- Over-engineered solutions for a simple problem
- Unnecessary abstraction layers with only one implementation
- Premature generalisation (generic framework code for a single use case)
- Overly complex conditionals that can be simplified

### 2d. Exposed Secrets / Sensitive Data

Flag any of the following appearing as literals in source code:
- Passwords, tokens, API keys, private keys, certificates
- Connection strings with embedded credentials
- Hardcoded IPs/hostnames that look like production infrastructure
- Any string matching common secret patterns: `secret`, `password`, `token`, `key`, `credential`, `api_key`, `access_key`, `private_key`, `-----BEGIN`

### 2e. Testability

- Is the class/method directly unit-testable without a running container, DB, or network?
- Are dependencies injected (constructor injection preferred) or hard-wired?
- Are there static calls to non-pure utilities that make mocking impossible?
- Does the method do too much to be tested in isolation?

### 2f. Maintainability

- Are method and variable names self-explanatory?
- Is cyclomatic complexity high (deep nesting, many branches)?
- Are there TODO/FIXME comments left unresolved?
- Is error handling present where failures are plausible?
- Is logging meaningful (structured, with appropriate levels)?

---

## Step 3 — Produce the Report

Output the report in the following structure. **Skip any section that has zero findings** — do not print empty headings.

```
## Code Review Report
**Scope:** changed/new code only  
**Files reviewed:** <list>

---

### 🔴 Critical — Secrets Exposed
| File | Line | Finding | Recommendation |
|------|------|---------|----------------|
| ...  | ...  | ...     | ...            |

---

### 🟠 SOLID Violations
| File | Line | Principle | Finding | Recommendation |
|------|------|-----------|---------|----------------|

---

### 🟡 DRY Violations
| File | Line | Finding | Recommendation |
|------|------|---------|----------------|

---

### 🟡 KISS Violations
| File | Line | Finding | Recommendation |
|------|------|---------|----------------|

---

### 🔵 Testability Issues
| File | Line | Finding | Recommendation |
|------|------|---------|----------------|

---

### 🔵 Maintainability Issues
| File | Line | Finding | Recommendation |
|------|------|---------|----------------|

---

### ✅ Summary
- **Total findings:** N  
- **Blocking (Critical):** N  
- **Recommended fixes:** N  
- **Overall verdict:** PASS / PASS WITH NOTES / NEEDS WORK
```

---

## Severity Rules

| Severity | Condition | Verdict impact |
|----------|-----------|----------------|
| 🔴 Critical | Any secret/credential exposed | Always → NEEDS WORK |
| 🟠 High | SOLID violation that breaks extensibility or hides bugs | → NEEDS WORK if ≥ 1 |
| 🟡 Medium | DRY / KISS violation | → PASS WITH NOTES |
| 🔵 Low | Testability / maintainability concern | → PASS WITH NOTES |

**Overall verdict logic:**
- Any 🔴 → `NEEDS WORK`
- Any 🟠 → `NEEDS WORK`
- Only 🟡/🔵 → `PASS WITH NOTES`
- Zero findings → `PASS`

---

## Rules

- **Never** review lines that were not changed. Quote only the changed lines (`+` lines from diff).
- **Do not** suggest refactoring unrelated legacy code.
- **Do not** invent findings — only report what is present in the diff.
- For Java projects: apply Spring best practices (constructor injection, `@Service`, `@Component`, no `@Autowired` on fields).
- Recommendations must be concrete and actionable (show a corrected snippet where helpful).
