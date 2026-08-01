#!/usr/bin/env bash
# Pre-commit code review gate
# Intercepts `git commit` tool calls and requires the springboot-peer-review skill to run first.
# Receives the Copilot PreToolUse hook payload on stdin (JSON).
#
# Bypass: set SKIP_REVIEW=1 to skip this gate (e.g. emergency hotfixes, amend with no code change).
# Example: SKIP_REVIEW=1 git commit -m "hotfix"

set -euo pipefail

# Allow explicit bypass via environment variable
if [[ "${SKIP_REVIEW:-0}" == "1" ]]; then
  exit 0
fi

input=$(cat)

# Parse both tool_name and command in a single Python3 call to avoid forking twice
read -r tool_name command < <(
  printf '%s' "$input" \
    | python3 -c "
import json, sys
d = json.load(sys.stdin)
tool = d.get('tool_name', '')
cmd  = d.get('tool_input', {}).get('command', '')
# Print on one line separated by a tab so read -r can split them
print(tool + '\t' + cmd)
" 2>/dev/null \
    | { IFS=$'\t' read -r t c; printf '%s\n%s\n' "$t" "$c"; } \
  || printf '\n\n'
)

# Gate only on run_in_terminal calls that invoke git commit (or git commit --amend).
# Use a regex to avoid false positives on strings like:
#   - echo "git commit"         (not an actual commit)
#   - git commit-graph          (different git subcommand)
if [[ "$tool_name" == "run_in_terminal" ]] && \
   [[ "$command" =~ (^|[[:space:];|&])git[[:space:]]+commit([[:space:]]|$) ]]; then
  cat <<'EOF'
{
  "systemMessage": "STOP: Before executing this git commit (including --amend), you MUST run the springboot-peer-review skill on staged changes first.\n\n1. Run: git diff --cached\n2. Apply ALL springboot-peer-review checks: SOLID, DRY, KISS, exposed secrets, testability, maintainability.\n3. Produce the full structured report.\n4. Only proceed with the commit if the overall verdict is PASS or PASS WITH NOTES.\n\nFor --amend: if the amend changes only the commit message (no code diff), the review can be skipped.\n\nIf the verdict is NEEDS WORK, fix the blocking issues before committing.\n\nTo bypass this gate in emergencies: SKIP_REVIEW=1 git commit ...",
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "Code review must pass before committing. Run the springboot-peer-review skill on staged changes first."
  }
}
EOF
  exit 0
fi

# All other tool calls: allow without intervention
exit 0
