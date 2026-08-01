#!/bin/bash
################################################################################
# GitHub Copilot Custom Agent Installer
# Version: 1.0.0
# Repository: https://github.com/sabirhussain/ai-code-assistance-agents
#
# This installer sets up custom GitHub Copilot agents system-wide by:
# - Installing agents to ~/.copilot/
# - Processing template files with variable substitution
# - Backing up existing installations
# - Providing comprehensive usage documentation
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/sabirhussain/ai-code-assistance-agents/main/github-agent-install.sh)
#
# Options:
#   -y, --yes           Non-interactive mode (use defaults)
#   -l, --local         Local testing mode (copy from current repo directory)
#   -h, --help          Show this help message
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

################################################################################
# Constants
################################################################################

VERSION="1.0.0"
REPO_OWNER="sabirhussain"
REPO_NAME="ai-code-assistance-agents"
REPO_BRANCH="main"
REPO_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}"
INSTALL_DIR="${HOME}/.copilot"
BACKUP_DIR="${HOME}/.copilot.backup-$(date +%Y%m%d-%H%M%S)"
NON_INTERACTIVE=false
LOCAL_MODE=false
LOCAL_REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║     GitHub Copilot Custom Agent Installer v${VERSION}          ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

show_help() {
    print_header
    cat << EOF
Install custom GitHub Copilot agents system-wide to ~/.copilot/

USAGE:
    # From GitHub (production)
    bash <(curl -fsSL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}/github-agent-install.sh)
    
    # Local testing mode
    ./github-agent-install.sh --local

OPTIONS:
    -y, --yes          Non-interactive mode (use defaults)
    -l, --local        Local testing mode (copy files from current repo directory)
    -h, --help         Show this help message

WHAT GETS INSTALLED:
    - Custom agents (TDD Generator, SpringBoot Peer Review)
    - Skills (write-failing-test, code-review)
    - Configuration templates
    - Pattern files
    - Usage guide

INSTALLATION DIRECTORY:
    ~/.copilot/

BACKUP:
    Existing installations are backed up to ~/.copilot.backup-TIMESTAMP

For more information, visit:
    https://github.com/${REPO_OWNER}/${REPO_NAME}

EOF
}

################################################################################
# Pre-flight Checks
################################################################################

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed."
        log_error "Please install curl and try again."
        exit 1
    fi
    
    # Check for basic Unix tools
    if ! command -v date &> /dev/null; then
        log_error "date command not found. This script requires a POSIX-compliant system."
        exit 1
    fi
    
    # Test network connectivity
    if [ "${LOCAL_MODE}" = true ]; then
        log_info "Local testing mode: Using files from ${LOCAL_REPO_DIR}"
        
        # Verify .github directory exists
        if [ ! -d "${LOCAL_REPO_DIR}/.github" ]; then
            log_error "Local mode requires running from repository root"
            log_error "Missing directory: ${LOCAL_REPO_DIR}/.github"
            exit 1
        fi
        log_success "Local repository directory found"
    else
        log_info "Testing connectivity to GitHub..."
        if ! curl -fsSL --connect-timeout 10 "${REPO_URL}/.github/about-me.md" &> /dev/null; then
            log_error "Cannot reach GitHub repository."
            log_error "Please check your internet connection and try again."
            log_error "Repository URL: ${REPO_URL}"
            exit 1
        fi
        log_success "GitHub repository is accessible"
    fi
    
    # Check write permissions for home directory
    if [ ! -w "${HOME}" ]; then
        log_error "No write permission in home directory: ${HOME}"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

################################################################################
# Backup Functions
################################################################################

backup_existing_installation() {
    if [ -d "${INSTALL_DIR}" ] && [ "$(ls -A ${INSTALL_DIR} 2>/dev/null)" ]; then
        log_info "Existing installation found at ${INSTALL_DIR}"
        log_info "Creating backup at ${BACKUP_DIR}..."
        
        cp -R "${INSTALL_DIR}" "${BACKUP_DIR}"
        log_success "Backup created successfully"
        echo "Backup location: ${BACKUP_DIR}"
    else
        log_info "No existing installation found, skipping backup"
    fi
}

################################################################################
# User Input Functions
################################################################################

collect_user_input() {
    log_info "Collecting configuration values..."
    
    if [ "${NON_INTERACTIVE}" = true ]; then
        log_info "Non-interactive mode: using defaults"
        LANG_VERSION="17"
        BUILD_TOOL="Maven"
        SPRING_BOOT_VERSION="3.5.11"
        BASE_PACKAGE="com.example.app"
    else
        echo ""
        echo "Please provide configuration values (press Enter for defaults):"
        echo ""
        
        read -p "Java version [17]: " LANG_VERSION
        LANG_VERSION=${LANG_VERSION:-17}
        
        read -p "Build tool (Maven/Gradle) [Maven]: " BUILD_TOOL
        BUILD_TOOL=${BUILD_TOOL:-Maven}
        
        read -p "Spring Boot version [3.5.11]: " SPRING_BOOT_VERSION
        SPRING_BOOT_VERSION=${SPRING_BOOT_VERSION:-3.5.11}
        
        read -p "Base package [com.example.app]: " BASE_PACKAGE
        BASE_PACKAGE=${BASE_PACKAGE:-com.example.app}
    fi
    
    # Derive paths from base package
    PACKAGE_PATH=$(echo "${BASE_PACKAGE}" | tr '.' '/')
    TEST_PATH="src/test/java/${PACKAGE_PATH}"
    MAIN_PATH="src/main/java/${PACKAGE_PATH}"
    
    log_success "Configuration collected"
}

################################################################################
# Download Functions
################################################################################

download_file() {
    local source_path="$1"
    local target_path="$2"
    
    if [ "${LOCAL_MODE}" = true ]; then
        # Local mode: copy from repository directory
        local local_file="${LOCAL_REPO_DIR}/${source_path}"
        
        log_info "Copying (local): ${source_path}"
        
        if [ ! -f "${local_file}" ]; then
            log_error "Local file not found: ${local_file}"
            return 1
        fi
        
        if cp "${local_file}" "${target_path}"; then
            return 0
        else
            log_error "Failed to copy: ${source_path}"
            return 1
        fi
    else
        # Production mode: download from GitHub
        local url="${REPO_URL}/${source_path}"
        
        log_info "Downloading: ${source_path}"
        
        if curl -fsSL "${url}" -o "${target_path}"; then
            return 0
        else
            log_error "Failed to download: ${source_path}"
            return 1
        fi
    fi
}

################################################################################
# Template Processing Functions
################################################################################

process_template() {
    local file_path="$1"
    
    log_info "Processing template: ${file_path}"
    
    # Replace template variables
    sed -i.bak \
        -e "s|{{COPILOT_HOME}}|${HOME}/.copilot|g" \
        -e "s|{{LANG_VERSION}}|${LANG_VERSION}|g" \
        -e "s|{{BUILD_TOOL}}|${BUILD_TOOL}|g" \
        -e "s|{{SPRING_BOOT_VERSION}}|${SPRING_BOOT_VERSION}|g" \
        -e "s|{{BASE_PACKAGE}}|${BASE_PACKAGE}|g" \
        -e "s|{{TEST_PATH}}|${TEST_PATH}|g" \
        -e "s|{{MAIN_PATH}}|${MAIN_PATH}|g" \
        "${file_path}"
    
    # Remove backup file
    rm -f "${file_path}.bak"
}

################################################################################
# Installation Functions
################################################################################

install_agents() {
    log_info "Installing custom agents..."
    
    mkdir -p "${INSTALL_DIR}/agents"
    
    local agents=("tdd-generator" "spring-boot-peer-review")
    
    for agent in "${agents[@]}"; do
        local source=".github/agents/${agent}.agent.md.template"
        local target="${INSTALL_DIR}/agents/${agent}.agent.md"
        
        if download_file "${source}" "${target}"; then
            process_template "${target}"
            log_success "Installed: ${agent} agent"
        else
            log_warning "Skipped: ${agent} agent (download failed)"
        fi
    done
}

install_skills() {
    log_info "Installing skills..."
    
    mkdir -p "${INSTALL_DIR}/skills/write-failing-test"
    mkdir -p "${INSTALL_DIR}/skills/code-review"
    
    # Install write-failing-test skill
    local source=".github/skills/write-failing-test/write-failing-test.skill.md.template"
    local target="${INSTALL_DIR}/skills/write-failing-test/write-failing-test.skill.md"
    
    if download_file "${source}" "${target}"; then
        process_template "${target}"
        log_success "Installed: write-failing-test skill"
    fi
    
    # Install code-review skill
    source=".github/skills/code-review/code-review.skill.md.template"
    target="${INSTALL_DIR}/skills/code-review/code-review.skill.md"
    
    if download_file "${source}" "${target}"; then
        process_template "${target}"
        log_success "Installed: code-review skill"
    fi
}

install_config() {
    log_info "Installing configuration files..."
    
    mkdir -p "${INSTALL_DIR}/config"
    mkdir -p "${INSTALL_DIR}/instructions"
    
    # Install config template
    local source=".github/config/copilot-config.template.yml"
    local target="${INSTALL_DIR}/config/copilot-config.yml"
    
    if download_file "${source}" "${target}"; then
        process_template "${target}"
        log_success "Installed: copilot-config.yml"
    fi
    
    # Install instructions
    source=".github/instructions/copilot-instructions.md.template"
    target="${INSTALL_DIR}/instructions/copilot-instructions.md"
    
    if download_file "${source}" "${target}"; then
        process_template "${target}"
        log_success "Installed: copilot-instructions.md"
    fi
}

install_patterns() {
    log_info "Installing pattern files..."
    
    mkdir -p "${INSTALL_DIR}/patterns"
    
    local patterns=("test-patterns.yml" "review-patterns.yml")
    
    for pattern in "${patterns[@]}"; do
        local source=".github/patterns/${pattern}"
        local target="${INSTALL_DIR}/patterns/${pattern}"
        
        if download_file "${source}" "${target}"; then
            log_success "Installed: ${pattern}"
        else
            log_warning "Skipped: ${pattern} (not found or download failed)"
        fi
    done
}

install_usage_guide() {
    log_info "Installing usage guide..."
    
    local source=".github/docs/USAGE.md.template"
    local target="${INSTALL_DIR}/USAGE.md"
    
    if download_file "${source}" "${target}"; then
        # No template processing needed for usage guide
        log_success "Installed: USAGE.md"
        return 0
    else
        log_warning "Usage guide not available (this is optional)"
        return 1
    fi
}

################################################################################
# Verification Functions
################################################################################

verify_installation() {
    log_info "Verifying installation..."
    
    local errors=0
    local expected_files=(
        "agents/tdd-generator.agent.md"
        "agents/spring-boot-peer-review.agent.md"
        "skills/write-failing-test/write-failing-test.skill.md"
        "skills/code-review/code-review.skill.md"
        "config/copilot-config.yml"
        "instructions/copilot-instructions.md"
    )
    
    for file in "${expected_files[@]}"; do
        if [ ! -f "${INSTALL_DIR}/${file}" ]; then
            log_error "Missing: ${file}"
            ((errors++))
        fi
    done
    
    if [ ${errors} -eq 0 ]; then
        log_success "Installation verified successfully"
        return 0
    else
        log_error "Installation incomplete: ${errors} file(s) missing"
        return 1
    fi
}

################################################################################
# Summary Display
################################################################################

display_summary() {
    local usage_guide_exists=false
    [ -f "${INSTALL_DIR}/USAGE.md" ] && usage_guide_exists=true
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    Installation Complete!                      ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📂 Installation Directory:"
    echo "   ${INSTALL_DIR}"
    echo ""
    
    if [ -d "${BACKUP_DIR}" ]; then
        echo "💾 Backup Location:"
        echo "   ${BACKUP_DIR}"
        echo ""
    fi
    
    echo "🤖 Installed Agents:"
    echo "   • tdd-generator            - TDD unit test generator"
    echo "   • spring-boot-peer-review  - Java/Spring Boot peer reviewer"
    echo ""
    
    echo "🎯 Configuration:"
    echo "   • Java Version:      ${LANG_VERSION}"
    echo "   • Build Tool:        ${BUILD_TOOL}"
    echo "   • Spring Boot:       ${SPRING_BOOT_VERSION}"
    echo "   • Base Package:      ${BASE_PACKAGE}"
    echo ""
    
    if [ "${usage_guide_exists}" = true ]; then
        echo "📖 Usage Guide:"
        echo "   ${INSTALL_DIR}/USAGE.md"
        echo ""
        echo "   Read the guide for detailed usage instructions:"
        echo "   $ cat ~/.copilot/USAGE.md"
        echo ""
    fi
    
    echo "🚀 Next Steps:"
    echo "   1. Start using agents in any repository with GitHub Copilot CLI"
    echo "   2. Customize ~/.copilot/config/copilot-config.yml for your projects"
    if [ "${usage_guide_exists}" = true ]; then
        echo "   3. Read ~/.copilot/USAGE.md for examples and best practices"
    fi
    echo ""
    
    echo "💡 Quick Start:"
    echo "   # Generate tests for a feature"
    echo "   $ gh copilot agent tdd-generator"
    echo ""
    echo "   # Review code changes"
    echo "   $ gh copilot agent spring-boot-peer-review"
    echo ""
    
    log_success "Installation completed successfully!"
}

################################################################################
# Main Function
################################################################################

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes)
                NON_INTERACTIVE=true
                shift
                ;;
            -l|--local)
                LOCAL_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    print_header
    
    # Execute installation steps
    check_prerequisites
    backup_existing_installation
    collect_user_input
    
    echo ""
    log_info "Starting installation..."
    echo ""
    
    install_agents
    install_skills
    install_config
    install_patterns
    install_usage_guide || true  # Optional, don't fail if missing
    
    echo ""
    verify_installation
    
    display_summary
}

# Run main function
main "$@"
