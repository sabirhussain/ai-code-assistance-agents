---
name: Draft PR Description
description: "Draft a pull request title and description from the current branch diff. Use when opening a PR or writing a PR summary."
argument-hint: "Optional: target base branch (default: main). Example: develop"
agent: agent
tools: [run_in_terminal]
---

# Draft Pull Request Description

## Instructions

You are a senior engineer writing a clear, professional pull request description.

### Step 1 — Gather context

Run the following commands and collect their output:

```bash
# 1. Detect the base branch (use the argument if provided, otherwise auto-detect)
git remote show origin | grep 'HEAD branch' | awk '{print $NF}'

# 2. Get the diff between this branch and the base branch
git diff $(git merge-base HEAD origin/main)..HEAD

# 3. List changed files with change type
git diff --name-status $(git merge-base HEAD origin/main)..HEAD

# 4. Get the commit log for this branch
git log --oneline $(git merge-base HEAD origin/main)..HEAD
```

> If the user supplied a base branch argument, replace `origin/main` with `origin/<argument>`.

### Step 2 — Analyse the diff

From the diff, extract:

- **What changed**: new features, bug fixes, refactors, config changes, test additions
- **Why it changed** (infer from commit messages and code intent)
- **Scope of impact**: which modules / layers are affected (e.g., controller, service, repository)
- **Any risks or caveats** (e.g., DB migration, breaking API change, feature flag needed)

### Step 3 — Produce the PR description

Output the following template filled in with real content. Keep it concise but complete.

---

```markdown
## [Suggested PR Title]
<!-- Active voice, present tense, ≤72 chars. e.g. "Add rate-limiting to ChatController" -->

---

## Summary
<!-- 2-4 sentences: what this PR does and why. -->

## Changes
<!-- Bullet list grouped by type. Use sub-bullets for detail. -->

### Added
- 

### Changed
- 

### Fixed
- 

### Removed
- 

### Tests
- 

## Impact & Risk
<!-- Breaking changes, DB migrations, env-var additions, feature flags, performance notes.
     Write "None" if there are no risks. -->

## Checklist
- [ ] Tests added / updated for changed behaviour
- [ ] No secrets or credentials committed
- [ ] SOLID / DRY / KISS principles followed
- [ ] Logging is appropriate (level, message quality)
- [ ] Documentation updated if public API changed
```

---

### Rules

- Omit sections that have nothing to say (e.g., no "Removed" entries → drop that section).
- Use present tense and active voice throughout ("Add X", not "Added X" or "Adds X").
- Do NOT include the raw diff or commit hashes in the output.
- Keep the summary focused — this is for a human reviewer, not a changelog.
