#!/usr/bin/env bash
# Pre-commit code review gate
# Intercepts `git commit` tool calls and requires the code-review skill to run first.
# Receives the Copilot PreToolUse hook payload on stdin (JSON).

set -euo pipefail

input=$(cat)

# Parse tool name and command from the hook payload using Python (reliable JSON parsing)
tool_name=$(printf '%s' "$input" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null \
  || echo "")

command=$(printf '%s' "$input" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null \
  || echo "")

# Only gate on run_in_terminal calls that include a git commit
if [[ "$tool_name" == "run_in_terminal" && "$command" == *"git commit"* ]]; then
  cat <<'EOF'
{
  "systemMessage": "STOP: Before executing this git commit, you MUST run the code-review skill on staged changes first.\n\n1. Run: git diff --cached\n2. Apply ALL code-review checks: SOLID, DRY, KISS, exposed secrets, testability, maintainability.\n3. Produce the full structured report.\n4. Only proceed with the commit if the overall verdict is PASS or PASS WITH NOTES.\n\nIf the verdict is NEEDS WORK, fix the blocking issues before committing.",
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "Code review must pass before committing. Run the code-review skill on staged changes first."
  }
}
EOF
  exit 0
fi

# All other tool calls: allow without intervention
exit 0
