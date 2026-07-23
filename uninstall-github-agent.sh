#!/bin/bash
################################################################################
# GitHub Copilot Custom Agents Uninstaller
# Removes only files installed by github-agent-install.sh
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="${HOME}/.copilot"
BACKUP_DIR="${HOME}/.copilot.uninstall-backup-$(date +%Y%m%d-%H%M%S)"

echo -e "${BLUE}[INFO]${NC} GitHub Copilot Custom Agents Uninstaller"
echo ""

# Check if installation exists
if [ ! -d "${INSTALL_DIR}" ]; then
    echo -e "${YELLOW}[WARNING]${NC} No installation found at ${INSTALL_DIR}"
    exit 0
fi

# Ask for confirmation
echo -e "${YELLOW}[WARNING]${NC} This will remove the following:"
echo "  - ${INSTALL_DIR}/agents/tdd-generator.agent.md"
echo "  - ${INSTALL_DIR}/agents/code-review.agent.md"
echo "  - ${INSTALL_DIR}/skills/write-failing-test/write-failing-test.skill.md"
echo "  - ${INSTALL_DIR}/skills/code-review/code-review.skill.md"
echo "  - ${INSTALL_DIR}/config/copilot-config.yml"
echo "  - ${INSTALL_DIR}/patterns/test-patterns.yml"
echo "  - ${INSTALL_DIR}/patterns/review-patterns.yml"
echo "  - ${INSTALL_DIR}/instructions/copilot-instructions.md"
echo "  - ${INSTALL_DIR}/USAGE.md"
echo ""
read -p "Create backup before removing? [Y/n]: " CREATE_BACKUP
CREATE_BACKUP=${CREATE_BACKUP:-Y}

# Create backup if requested
if [[ "${CREATE_BACKUP}" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}[INFO]${NC} Creating backup at ${BACKUP_DIR}..."
    mkdir -p "${BACKUP_DIR}"
    cp -R "${INSTALL_DIR}" "${BACKUP_DIR}/"
    echo -e "${GREEN}[SUCCESS]${NC} Backup created at ${BACKUP_DIR}"
fi

echo -e "${BLUE}[INFO]${NC} Removing installed files..."

# Remove individual files
rm -f "${INSTALL_DIR}/agents/tdd-generator.agent.md"
rm -f "${INSTALL_DIR}/agents/code-review.agent.md"
rm -f "${INSTALL_DIR}/skills/write-failing-test/write-failing-test.skill.md"
rm -f "${INSTALL_DIR}/skills/code-review/code-review.skill.md"
rm -f "${INSTALL_DIR}/config/copilot-config.yml"
rm -f "${INSTALL_DIR}/patterns/test-patterns.yml"
rm -f "${INSTALL_DIR}/patterns/review-patterns.yml"
rm -f "${INSTALL_DIR}/instructions/copilot-instructions.md"
rm -f "${INSTALL_DIR}/USAGE.md"

# Remove only the specific skill subdirectories if they are empty
rmdir "${INSTALL_DIR}/skills/write-failing-test" 2>/dev/null || true
rmdir "${INSTALL_DIR}/skills/code-review" 2>/dev/null || true

# Note: We do NOT remove parent directories (agents, skills, instructions, patterns)
# as they may contain other custom agents, skills, or configurations

echo -e "${YELLOW}[NOTE]${NC} Directories preserved (may contain other files):"
echo "  - ${INSTALL_DIR}/agents/"
echo "  - ${INSTALL_DIR}/skills/"
echo "  - ${INSTALL_DIR}/config/"
echo "  - ${INSTALL_DIR}/patterns/"
echo "  - ${INSTALL_DIR}/instructions/"

echo ""
echo -e "${GREEN}[SUCCESS]${NC} Uninstall complete!"

if [[ "${CREATE_BACKUP}" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Backup location: ${BACKUP_DIR}"
    echo "To restore:"
    echo "  cp -R ${BACKUP_DIR}/.copilot ${HOME}/"
fi