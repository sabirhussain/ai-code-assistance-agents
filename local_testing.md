# Local Testing Guide

This guide explains how to test the installer locally before pushing to GitHub.

## Prerequisites

- The installer script (`github-agent-install.sh`)

## Setup Local Testing Environment

### Run Installer in Local Mode

From the repository root:

```bash
cd /path/to/ai-code-assistance-agents
./github-agent-install.sh --local
```

## Testing Scenarios

### Scenario 1: Test with Default Configuration

```bash
# Run installer non-interactively
./github-agent-install.sh --local -y
```

**Verifies**:

- ✅ Default port (8000) works
- ✅ Non-interactive mode with defaults
- ✅ Files download from local server
- ✅ Template variables are substituted

### Scenario 2: Test with Custom Port

```bash
# Run installer with custom port (assumes server on port 9090)
./github-agent-install.sh --local 9090
```

**Verifies**:

- ✅ Custom port support
- ✅ Interactive mode prompts

### Scenario 3: Test Backup Functionality

```bash
# Create existing installation
mkdir -p ~/.copilot/agents
echo "test" > ~/.copilot/agents/test.md

# Run installer
./github-agent-install.sh --local -y

# Verify backup was created
ls -d ~/.copilot.backup-*

# Test uninstaller
./uninstall-github-agent.sh
```

**Verifies**:

- ✅ Backup creation
- ✅ Timestamped backup directory
- ✅ Original files preserved

### Scenario 4: Test Template Processing

```bash
# Run installer
./github-agent-install.sh --local -y

# Check for template placeholders
grep -r "{{" ~/.copilot/
# Should return nothing (all placeholders replaced)
```

**Verifies**:

- ✅ All `{{VARIABLES}}` replaced
- ✅ Config values applied correctly
- ✅ Derived paths computed

## Troubleshooting Local Testing

### Issue: "Cannot reach local server"

**Symptoms**:

```
[ERROR] Cannot reach local server at http://localhost:8000
```

**Solutions**:

1. Verify local server is running: `curl http://localhost:8000/`
2. Check correct port: `./github-agent-install.sh --local [PORT]`
3. Ensure no firewall blocking localhost

### Issue: "404 Not Found" for template files

**Symptoms**:
Files download but show 404 errors

**Solutions**:

1. Start server from repository root (not subdirectory)
2. Verify paths: `curl http://localhost:8000/.github/agents/tdd-generator.agent.md.template`
3. Check file exists in repository

### Issue: Template variables not replaced

**Symptoms**:
Installed files contain `{{COPILOT_HOME}}` or similar placeholders

**Solutions**:

1. Check sed is available: `which sed`
2. Verify macOS vs Linux sed syntax
3. Check process_template function in installer

## Comparison: Local vs Production

| Aspect   | Local Mode              | Production Mode                         |
|----------|-------------------------|-----------------------------------------|
| URL      | `http://localhost:PORT` | `https://raw.githubusercontent.com/...` |
| Network  | No internet needed      | Requires internet                       |
| Changes  | Immediate (local files) | After git push                          |
| Speed    | Fast (local)            | Depends on network                      |
| Use Case | Development/testing     | End users                               |

## Best Practices

1. **Test before pushing**: Always test locally first
2. **Use non-interactive mode**: Faster for repeated tests (`-y`)
3. **Clean between tests**: Remove `~/.copilot/` for clean slate
4. **Check backups**: Verify backup creation works
5. **Verify templates**: Ensure no `{{PLACEHOLDERS}}` remain

## Quick Test Script

Create a comprehensive test script:

```bash
#!/bin/bash
# test-local-install.sh

set -e

echo "=== Starting Local Installer Test ==="

# 1. Backup existing installation
if [ -d ~/.copilot ]; then
    echo "Backing up existing ~/.copilot..."
    mv ~/.copilot ~/.copilot.test-backup
fi

# 2. Run installer
echo "Running installer in local mode..."
./github-agent-install.sh --local -y

# 3. Verify installation
echo "Verifying installation..."
test -f ~/.copilot/agents/tdd-generator.agent.md
test -f ~/.copilot/agents/spring-boot-peer-review.agent.md
test -f ~/.copilot/config/copilot-config.yml
test -f ~/.copilot/USAGE.md

# 4. Check for placeholders
echo "Checking for unreplaced placeholders..."
if grep -r "{{" ~/.copilot/ 2>/dev/null; then
    echo "ERROR: Found unreplaced placeholders!"
    exit 1
fi

# 5. Test uninstaller
echo "Testing uninstaller..."
echo "n" | ./uninstall-github-agent.sh

# 6. Cleanup
echo "Cleaning up..."
rm -rf ~/.copilot
if [ -d ~/.copilot.test-backup ]; then
    mv ~/.copilot.test-backup ~/.copilot
fi

echo "✓ All tests passed!"
```

Run it:

```bash
chmod +x test-local-install.sh
./test-local-install.sh
```

## Integration Testing

After local tests pass, test from GitHub:

```bash
# Push changes
git add github-agent-install.sh
git commit -m "Add local testing mode"
git push origin main

# Test from GitHub
bash <(curl -fsSL https://raw.githubusercontent.com/sabirhussain/ai-code-assistance-agents/main/github-agent-install.sh) -y
```

## Continuous Testing

For ongoing development, ensure your local server is running and then:

```bash
# Quick test loop
while true; do
    ./uninstall-github-agent.sh
    ./github-agent-install.sh --local -y
    echo "Test completed at $(date)"
    sleep 5
done
```

Press Ctrl+C to stop the loop.

---

**Remember**: Local mode is for testing only. End users should always use the production curl command from GitHub.
