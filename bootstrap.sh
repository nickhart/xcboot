#!/usr/bin/env bash
set -euo pipefail

# xcboot - Bootstrap Tool for iOS Projects
# Installs CI, quality tools, helper scripts, and optional MVVM structure
# into existing or new Xcode projects
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/nickhart/xcboot/main/bootstrap.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/nickhart/xcboot/main/bootstrap.sh | bash -s -- --force

# Version
readonly XCBOOT_VERSION="0.1.0"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Logging functions
log_info() {
  echo -e "${BLUE}INFO:${NC} $*"
}

log_success() {
  echo -e "${GREEN}SUCCESS:${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}WARNING:${NC} $*"
}

log_error() {
  echo -e "${RED}ERROR:${NC} $*" >&2
}

log_step() {
  echo -e "${CYAN}${BOLD}→${NC} $*"
}

# Configuration
FORCE_INSTALL=false
TEMPLATE="default"
GENERATE_STATUS=true
CREATE_STRUCTURE=false

# Parse arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --force)
        FORCE_INSTALL=true
        shift
        ;;
      --template)
        TEMPLATE="$2"
        shift 2
        ;;
      --no-status)
        GENERATE_STATUS=false
        shift
        ;;
      --structure)
        CREATE_STRUCTURE=true
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        echo "Use '$0 --help' for usage information"
        exit 1
        ;;
    esac
  done
}

show_help() {
  cat <<EOF
${BOLD}xcboot - Bootstrap Tool for iOS Projects${NC}

Installs CI, quality tools, helper scripts, and optional MVVM structure
into existing or new Xcode projects.

${BOLD}USAGE:${NC}
  curl -fsSL https://raw.githubusercontent.com/nickhart/xcboot/main/bootstrap.sh | bash
  curl -fsSL https://raw.githubusercontent.com/nickhart/xcboot/main/bootstrap.sh | bash -s -- [OPTIONS]

${BOLD}OPTIONS:${NC}
  --force          Overwrite existing files (for upgrades)
  --template NAME  Use specific template (default: default)
  --no-status      Skip STATUS.md generation
  --structure      Create MVVM directory structure
  --help           Show this help message

${BOLD}EXAMPLES:${NC}
  # Bootstrap existing Xcode project
  cd MyApp && curl -fsSL https://...bootstrap.sh | bash

  # Force upgrade to latest version
  curl -fsSL https://...bootstrap.sh | bash -s -- --force

  # Create with MVVM structure
  curl -fsSL https://...bootstrap.sh | bash -s -- --structure

${BOLD}WHAT IT DOES:${NC}
  • Detects your Xcode project and git provider
  • Installs automation scripts (build, test, lint, format, preflight)
  • Configures SwiftLint and SwiftFormat
  • Sets up CI/CD (GitHub Actions, GitLab CI, or Bitbucket Pipelines)
  • Auto-configures iOS simulators
  • Installs git pre-commit hooks
  • Optionally creates STATUS.md and MVVM structure

${BOLD}VERSION:${NC} $XCBOOT_VERSION

EOF
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check required dependencies
check_dependencies() {
  log_step "Checking dependencies..."

  local missing_deps=()

  if ! command_exists git; then
    missing_deps+=("git")
  fi

  if ! command_exists xcodebuild; then
    missing_deps+=("xcodebuild (Xcode)")
  fi

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    log_error "Missing required dependencies: ${missing_deps[*]}"
    log_info "Please install missing dependencies and try again"
    exit 1
  fi

  log_success "All required dependencies present"
}

# Detect git provider
detect_git_provider() {
  if [[ ! -d ".git" ]]; then
    echo "none"
    return
  fi

  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")

  case "$remote_url" in
    *github.com*)    echo "github" ;;
    *gitlab.com*)    echo "gitlab" ;;
    *bitbucket.*)    echo "bitbucket" ;;
    *)               echo "github" ;;  # Default to GitHub
  esac
}

# Detect project name from .xcodeproj
detect_project_name() {
  local xcodeproj
  xcodeproj=$(find . -maxdepth 1 -name "*.xcodeproj" -type d | head -1)

  if [[ -n "$xcodeproj" ]]; then
    basename "$xcodeproj" .xcodeproj
    return 0
  fi

  # Try xcodegen dump if available
  if command_exists xcodegen && [[ -f "project.yml" ]]; then
    if command_exists yq; then
      yq eval '.name' project.yml 2>/dev/null || echo ""
      return 0
    fi
  fi

  echo ""
  return 1
}

# Detect deployment target from .xcodeproj
detect_deployment_target() {
  local xcodeproj="$1"

  if [[ -z "$xcodeproj" ]] || [[ ! -d "$xcodeproj" ]]; then
    echo "18.0"  # Default
    return
  fi

  # Try to extract from project.pbxproj
  local pbxproj="$xcodeproj/project.pbxproj"
  if [[ -f "$pbxproj" ]]; then
    local target
    target=$(grep -m 1 "IPHONEOS_DEPLOYMENT_TARGET" "$pbxproj" | sed 's/.*= \(.*\);/\1/' | tr -d ' "' || echo "")
    if [[ -n "$target" ]]; then
      echo "$target"
      return
    fi
  fi

  # Try from project.yml if using xcodegen
  if [[ -f "project.yml" ]] && command_exists yq; then
    local yml_target
    yml_target=$(yq eval '.options.deploymentTarget.iOS' project.yml 2>/dev/null || echo "")
    if [[ -n "$yml_target" && "$yml_target" != "null" ]]; then
      echo "$yml_target"
      return
    fi
  fi

  echo "18.0"  # Default
}

# Detect Swift version
detect_swift_version() {
  if command_exists swift; then
    swift --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "6.2"
  else
    echo "6.2"  # Default
  fi
}

# Detect Mac architecture for simulators
detect_mac_architecture() {
  case "$(uname -m)" in
    arm64) echo "arm64" ;;
    x86_64) echo "x86_64" ;;
    *) echo "arm64" ;; # Default to Apple Silicon
  esac
}

# Detect optimal simulator based on deployment target
detect_optimal_simulator() {
  local deployment_target="$1"
  local major_version="${deployment_target%%.*}"

  # Default simulators based on iOS version
  case "$major_version" in
    18)
      echo "iPhone 16 Pro|18-0"
      ;;
    17)
      echo "iPhone 15 Pro|17-5"
      ;;
    16)
      echo "iPhone 15 Pro|16-4"
      ;;
    *)
      echo "iPhone 16 Pro|18-0"
      ;;
  esac
}

# Show banner
show_banner() {
  cat <<EOF

${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${BOLD}             xcboot v${XCBOOT_VERSION}${NC}
${BOLD}    Bootstrap Tool for iOS Projects${NC}
${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

EOF
}

# Prompt for bundle ID if not detected
prompt_bundle_id() {
  local project_name="$1"
  local default_bundle_id="com.yourcompany"

  # Try to detect from existing project
  local xcodeproj="${project_name}.xcodeproj"
  if [[ -f "$xcodeproj/project.pbxproj" ]]; then
    local detected
    detected=$(grep -m 1 "PRODUCT_BUNDLE_IDENTIFIER" "$xcodeproj/project.pbxproj" | sed 's/.*= \(.*\);/\1/' | tr -d ' "' | sed 's/\.[^.]*$//' || echo "")
    if [[ -n "$detected" && "$detected" != "\$(PRODUCT_BUNDLE_IDENTIFIER)" ]]; then
      default_bundle_id="$detected"
    fi
  fi

  # If stdin is not a terminal (piped input), use default
  if [[ ! -t 0 ]]; then
    echo "$default_bundle_id"
    return
  fi

  echo -n "Enter bundle ID root [$default_bundle_id]: "
  read -r bundle_id

  if [[ -z "$bundle_id" ]]; then
    echo "$default_bundle_id"
  else
    echo "$bundle_id"
  fi
}

# Download file from GitHub (or use local files for testing)
download_file() {
  local template="$1"
  local file_path="$2"

  # Support local testing mode via XCBOOT_LOCAL_PATH environment variable
  if [[ -n "${XCBOOT_LOCAL_PATH:-}" ]]; then
    local local_file="${XCBOOT_LOCAL_PATH}/templates/${template}/${file_path}"
    if [[ -f "$local_file" ]]; then
      cat "$local_file"
      return 0
    else
      log_error "Local file not found: $local_file"
      return 1
    fi
  fi

  # Normal mode: download from GitHub
  local url="https://raw.githubusercontent.com/nickhart/xcboot/main/templates/${template}/${file_path}"

  if command_exists curl; then
    curl -fsSL "$url"
  elif command_exists wget; then
    wget -qO- "$url"
  else
    log_error "Neither curl nor wget found"
    exit 1
  fi
}

# Replace template variables in content
replace_variables() {
  local content="$1"
  local project_name="$2"
  local bundle_id_root="$3"
  local deployment_target="$4"
  local swift_version="$5"
  local ci_provider="$6"
  local sim_device="$7"
  local sim_os="$8"
  local sim_arch="$9"

  content="${content//\{\{PROJECT_NAME\}\}/$project_name}"
  content="${content//\{\{BUNDLE_ID_ROOT\}\}/$bundle_id_root}"
  content="${content//\{\{DEPLOYMENT_TARGET\}\}/$deployment_target}"
  content="${content//\{\{SWIFT_VERSION\}\}/$swift_version}"
  content="${content//\{\{CI_PROVIDER\}\}/$ci_provider}"
  content="${content//\{\{SIMULATOR_TESTS_NAME\}\}/xcboot-test-sim}"
  content="${content//\{\{SIMULATOR_TESTS_DEVICE\}\}/$sim_device}"
  content="${content//\{\{SIMULATOR_TESTS_OS\}\}/$sim_os}"
  content="${content//\{\{SIMULATOR_TESTS_ARCH\}\}/$sim_arch}"
  content="${content//\{\{SIMULATOR_UI_TESTS_NAME\}\}/xcboot-ui-test-sim}"
  content="${content//\{\{SIMULATOR_UI_TESTS_DEVICE\}\}/$sim_device}"
  content="${content//\{\{SIMULATOR_UI_TESTS_OS\}\}/$sim_os}"
  content="${content//\{\{SIMULATOR_UI_TESTS_ARCH\}\}/$sim_arch}"

  echo "$content"
}

# Install file from template
install_file() {
  local template="$1"
  local source_path="$2"
  local dest_path="$3"
  local project_name="$4"
  local bundle_id_root="$5"
  local deployment_target="$6"
  local swift_version="$7"
  local ci_provider="$8"
  local sim_device="$9"
  local sim_os="${10}"
  local sim_arch="${11}"

  # Check if file exists and force flag
  if [[ -f "$dest_path" ]] && [[ "$FORCE_INSTALL" != "true" ]]; then
    log_warning "File exists, skipping: $dest_path (use --force to overwrite)"
    return 0
  fi

  # Create parent directory if needed
  local parent_dir
  parent_dir=$(dirname "$dest_path")
  if [[ ! -d "$parent_dir" ]]; then
    mkdir -p "$parent_dir"
  fi

  # Download and process file
  local content
  content=$(download_file "$template" "$source_path")

  # Replace template variables
  content=$(replace_variables "$content" "$project_name" "$bundle_id_root" "$deployment_target" "$swift_version" "$ci_provider" "$sim_device" "$sim_os" "$sim_arch")

  # Write file
  echo "$content" > "$dest_path"

  log_success "Installed: $dest_path"
}

# Install scripts
install_scripts() {
  local template="$1"
  shift
  local vars=("$@")

  log_step "Installing scripts..."

  local scripts=(
    "_helpers.sh:scripts/_helpers.sh"
    "build.sh:scripts/build.sh"
    "test.sh:scripts/test.sh"
    "lint.sh:scripts/lint.sh"
    "format.sh:scripts/format.sh"
    "preflight.sh:scripts/preflight.sh"
    "simulator.sh:scripts/simulator.sh"
    "pre-commit.sh:scripts/pre-commit.sh"
  )

  for script_mapping in "${scripts[@]}"; do
    local source="${script_mapping%%:*}"
    local dest="${script_mapping##*:}"
    install_file "$template" "scripts/$source" "$dest" "${vars[@]}"
    chmod +x "$dest"
  done

  echo
}

# Install configs
install_configs() {
  local template="$1"
  shift
  local vars=("$@")

  log_step "Installing configuration files..."

  install_file "$template" "configs/swiftlint.yml" ".swiftlint.yml" "${vars[@]}"
  install_file "$template" "configs/swiftformat" ".swiftformat" "${vars[@]}"
  install_file "$template" ".xcboot/config.yml" ".xcboot/config.yml" "${vars[@]}"

  echo
}

# Install CI configuration based on provider
install_ci_config() {
  local template="$1"
  local provider="$2"
  shift 2
  local vars=("$@")

  log_step "Installing CI configuration for $provider..."

  case "$provider" in
    github)
      mkdir -p .github/workflows
      install_file "$template" "ci/github/workflows/ci.yml" ".github/workflows/ci.yml" "${vars[@]}"
      install_file "$template" "ci/github/pull_request_template.md" ".github/pull_request_template.md" "${vars[@]}"
      ;;
    gitlab)
      install_file "$template" "ci/gitlab/.gitlab-ci.yml" ".gitlab-ci.yml" "${vars[@]}"
      mkdir -p .gitlab/merge_request_templates
      install_file "$template" "ci/gitlab/merge_request_templates/default.md" ".gitlab/merge_request_templates/default.md" "${vars[@]}"
      log_warning "GitLab CI support is experimental"
      ;;
    bitbucket)
      install_file "$template" "ci/bitbucket/bitbucket-pipelines.yml" "bitbucket-pipelines.yml" "${vars[@]}"
      install_file "$template" "ci/bitbucket/pull_request_template.md" "pull_request_template.md" "${vars[@]}"
      log_warning "Bitbucket Pipelines support is experimental"
      ;;
    *)
      log_warning "No CI provider detected, skipping CI configuration"
      ;;
  esac

  echo
}

# Install git hooks
install_git_hooks() {
  if [[ ! -d ".git" ]]; then
    log_warning "Not a git repository, skipping git hooks"
    return
  fi

  log_step "Installing git hooks..."

  if [[ -f ".git/hooks/pre-commit" ]] && [[ "$FORCE_INSTALL" != "true" ]]; then
    log_warning "Pre-commit hook exists, skipping (use --force to overwrite)"
    return
  fi

  mkdir -p .git/hooks

  cat > .git/hooks/pre-commit <<'EOF'
#!/usr/bin/env bash
# xcboot pre-commit hook
# Runs preflight checks before commit

if [[ -f "./scripts/pre-commit.sh" ]]; then
  ./scripts/pre-commit.sh
else
  echo "Warning: scripts/pre-commit.sh not found"
  exit 0
fi
EOF

  chmod +x .git/hooks/pre-commit
  log_success "Installed pre-commit hook"
  echo
}

# Install optional STATUS.md
install_status() {
  local template="$1"
  shift
  local vars=("$@")

  log_step "Installing STATUS.md..."
  install_file "$template" "STATUS.md" "STATUS.md" "${vars[@]}"
  echo
}

# Main bootstrap function
main() {
  parse_arguments "$@"
  show_banner

  # Step 1: Check dependencies
  check_dependencies
  echo

  # Step 2: Detect project
  log_step "Detecting project..."
  local project_name
  project_name=$(detect_project_name)

  if [[ -z "$project_name" ]]; then
    log_error "No Xcode project found in current directory"
    log_info "Make sure you're in a directory with a .xcodeproj file"
    log_info "Or use xcodegen with a project.yml file"
    exit 1
  fi

  log_success "Detected project: $project_name"
  echo

  # Step 3: Detect git provider
  log_step "Detecting git provider..."
  local git_provider
  git_provider=$(detect_git_provider)
  log_success "Git provider: $git_provider"
  echo

  # Step 4: Detect project metadata
  log_step "Detecting project metadata..."
  local xcodeproj="${project_name}.xcodeproj"
  local deployment_target
  deployment_target=$(detect_deployment_target "$xcodeproj")
  local swift_version
  swift_version=$(detect_swift_version)
  local mac_arch
  mac_arch=$(detect_mac_architecture)

  log_info "Deployment target: iOS $deployment_target"
  log_info "Swift version: $swift_version"
  log_info "Mac architecture: $mac_arch"
  echo

  # Step 5: Detect simulator configuration
  log_step "Detecting optimal simulator configuration..."
  local sim_config
  sim_config=$(detect_optimal_simulator "$deployment_target")
  local sim_device="${sim_config%%|*}"
  local sim_os="${sim_config##*|}"

  log_info "Simulator: $sim_device (iOS $sim_os)"
  echo

  # Step 6: Prompt for bundle ID
  log_step "Configuring bundle identifier..."
  local bundle_id_root
  bundle_id_root=$(prompt_bundle_id "$project_name")
  log_success "Bundle ID root: $bundle_id_root"
  echo

  # Prepare variables array for installation functions
  local vars=(
    "$project_name"
    "$bundle_id_root"
    "$deployment_target"
    "$swift_version"
    "$git_provider"
    "$sim_device"
    "$sim_os"
    "$mac_arch"
  )

  # Step 7: Install files
  log_step "Installing xcboot files..."
  echo

  install_scripts "$TEMPLATE" "${vars[@]}"
  install_configs "$TEMPLATE" "${vars[@]}"
  install_ci_config "$TEMPLATE" "$git_provider" "${vars[@]}"
  install_git_hooks

  if $GENERATE_STATUS; then
    install_status "$TEMPLATE" "${vars[@]}"
  fi

  # Step 8: Show success message and next steps
  log_success "xcboot installation complete!"
  echo
  log_info "What was installed:"
  echo "  • Scripts in ./scripts/"
  echo "  • Configuration files: .swiftlint.yml, .swiftformat, .xcboot/config.yml"
  echo "  • CI configuration for $git_provider"
  echo "  • Git pre-commit hook"
  if $GENERATE_STATUS; then
    echo "  • STATUS.md documentation"
  fi
  echo
  log_info "Next steps:"
  echo "  1. Review and customize .xcboot/config.yml if needed"
  echo "  2. Run ./scripts/simulator.sh to set up simulators"
  echo "  3. Run ./scripts/preflight.sh to verify everything works"
  echo "  4. Start using automation scripts: ./scripts/build.sh, ./scripts/test.sh"
  echo
  log_info "To upgrade xcboot in the future, run with --force flag"
  echo
}

# Run main function
main "$@"
