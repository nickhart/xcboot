#!/usr/bin/env bash
set -euo pipefail

# Integration test script for xcboot
# Tests the bootstrap.sh installer with mock Xcode projects
# All test execution happens in /tmp - NEVER modifies xcboot repo

XCBOOT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Use GitHub runner temp if available, otherwise /tmp for local testing
TEMP_BASE="${RUNNER_TEMP:-/tmp}"
TEST_ROOT="${TEMP_BASE}/xcboot-test-$(date +%s)"

KEEP_ARTIFACTS=false
VERBOSE=false

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

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

log_debug() {
  if $VERBOSE; then
    echo -e "${CYAN}DEBUG:${NC} $*"
  fi
}

# Show usage
show_usage() {
  cat <<EOF
${BOLD}xcboot Integration Test Suite${NC}

Tests bootstrap.sh with mock Xcode projects in /tmp (safe, isolated).

${BOLD}USAGE:${NC}
  ./scripts/integration-test.sh [OPTIONS]

${BOLD}OPTIONS:${NC}
  --keep-artifacts    Preserve test directories after completion
  --verbose          Show detailed output
  --help             Show this help message

${BOLD}EXAMPLES:${NC}
  # Run all tests
  ./scripts/integration-test.sh

  # Run tests and keep artifacts for inspection
  ./scripts/integration-test.sh --keep-artifacts

  # Verbose output
  ./scripts/integration-test.sh --verbose

${BOLD}SAFETY:${NC}
  • All tests run in isolated temp directory
    - GitHub CI: \$RUNNER_TEMP/xcboot-test-{timestamp}/
    - Local: /tmp/xcboot-test-{timestamp}/
  • Never modifies xcboot repository
  • Read-only access to xcboot source
  • Automatic cleanup on success
  • Preserves artifacts on failure

EOF
}

# Parse arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    --keep-artifacts)
      KEEP_ARTIFACTS=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help | -h)
      show_usage
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

# Safety check: ensure we're not in xcboot repo during tests
safety_check() {
  local current_dir
  current_dir=$(pwd)

  if [[ $current_dir == "$XCBOOT_ROOT"* ]] && [[ $current_dir != "$XCBOOT_ROOT" ]]; then
    log_error "Safety check failed: Running from inside xcboot subdirectory"
    log_error "Current: $current_dir"
    log_error "xcboot: $XCBOOT_ROOT"
    exit 1
  fi

  log_debug "Safety check passed"
}

# Create mock Xcode project
create_mock_project() {
  local project_dir="$1"
  local project_name="$2"
  local deployment_target="${3:-18.0}"
  local bundle_id="${4:-com.test.${project_name}}"

  log_debug "Creating mock project: $project_name in $project_dir"

  mkdir -p "$project_dir"
  cd "$project_dir"

  # Create .xcodeproj directory
  mkdir -p "${project_name}.xcodeproj"

  # Create minimal project.pbxproj
  cat >"${project_name}.xcodeproj/project.pbxproj" <<'PBXPROJ'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {
		buildSettings = {
			IPHONEOS_DEPLOYMENT_TARGET = DEPLOYMENT_TARGET_PLACEHOLDER;
			PRODUCT_BUNDLE_IDENTIFIER = BUNDLE_ID_PLACEHOLDER;
			SWIFT_VERSION = 6.2;
		};
	};
	rootObject = 00000000000000000000000;
}
PBXPROJ

  # Replace placeholders
  sed -i.bak "s/DEPLOYMENT_TARGET_PLACEHOLDER/$deployment_target/g" "${project_name}.xcodeproj/project.pbxproj"
  sed -i.bak "s/BUNDLE_ID_PLACEHOLDER/$bundle_id/g" "${project_name}.xcodeproj/project.pbxproj"
  rm -f "${project_name}.xcodeproj/project.pbxproj.bak"

  log_debug "Created mock project: ${project_name}.xcodeproj"
}

# Initialize git repo with specific provider
init_git_repo() {
  local provider="$1"

  git init -q
  git config user.email "test@example.com"
  git config user.name "Test User"

  case "$provider" in
  github)
    git remote add origin https://github.com/test/test.git
    ;;
  gitlab)
    git remote add origin https://gitlab.com/test/test.git
    ;;
  bitbucket)
    git remote add origin https://bitbucket.org/test/test.git
    ;;
  none)
    # No remote
    ;;
  *)
    log_error "Unknown provider: $provider"
    return 1
    ;;
  esac

  log_debug "Initialized git repo with provider: $provider"
}

# Run bootstrap.sh
run_bootstrap() {
  local flags="${1:-}"

  log_debug "Running bootstrap.sh with flags: $flags"

  # Set local path for testing (don't download from GitHub)
  export XCBOOT_LOCAL_PATH="$XCBOOT_ROOT"

  # Run bootstrap in non-interactive mode (pipe empty input)
  if $VERBOSE; then
    echo "" | bash "$XCBOOT_ROOT/bootstrap.sh" "$flags"
  else
    echo "" | bash "$XCBOOT_ROOT/bootstrap.sh" "$flags" >/dev/null 2>&1
  fi

  # Unset local path
  unset XCBOOT_LOCAL_PATH
}

# Verify file exists
verify_file_exists() {
  local file="$1"
  local description="${2:-$file}"

  if [[ ! -f $file ]]; then
    log_error "Missing file: $description"
    log_error "  Expected: $file"
    return 1
  fi

  log_debug "✓ Found: $description"
  return 0
}

# Verify directory exists
verify_dir_exists() {
  local dir="$1"
  local description="${2:-$dir}"

  if [[ ! -d $dir ]]; then
    log_error "Missing directory: $description"
    log_error "  Expected: $dir"
    return 1
  fi

  log_debug "✓ Found: $description"
  return 0
}

# Verify script is executable
verify_executable() {
  local script="$1"
  local description="${2:-$script}"

  if [[ ! -x $script ]]; then
    log_error "Not executable: $description"
    log_error "  File: $script"
    return 1
  fi

  log_debug "✓ Executable: $description"
  return 0
}

# Verify template variable was replaced
verify_template_replaced() {
  local file="$1"
  local variable="$2"
  local expected_value="$3"

  if ! grep -q "$expected_value" "$file"; then
    log_error "Template variable not replaced in $file"
    log_error "  Variable: $variable"
    log_error "  Expected: $expected_value"
    return 1
  fi

  log_debug "✓ Template variable replaced: $variable -> $expected_value"
  return 0
}

# Verify no template variables remain
verify_no_template_vars() {
  local file="$1"

  if grep -q "{{.*}}" "$file" 2>/dev/null; then
    log_error "Unreplaced template variables found in $file:"
    grep "{{.*}}" "$file" || true
    return 1
  fi

  log_debug "✓ No template variables in: $file"
  return 0
}

# Test 1: Basic installation
test_basic_installation() {
  log_step "Test 1: Basic installation"

  local test_dir="$TEST_ROOT/test-basic"
  create_mock_project "$test_dir" "TestApp"
  init_git_repo "github"

  # Run bootstrap
  run_bootstrap

  # Verify scripts installed
  local errors=0
  verify_dir_exists "scripts" || ((errors++))
  verify_file_exists "scripts/_helpers.sh" || ((errors++))
  verify_file_exists "scripts/build.sh" || ((errors++))
  verify_file_exists "scripts/test.sh" || ((errors++))
  verify_file_exists "scripts/lint.sh" || ((errors++))
  verify_file_exists "scripts/format.sh" || ((errors++))
  verify_file_exists "scripts/preflight.sh" || ((errors++))
  verify_file_exists "scripts/simulator.sh" || ((errors++))
  verify_file_exists "scripts/pre-commit.sh" || ((errors++))

  # Verify scripts are executable
  verify_executable "scripts/build.sh" || ((errors++))
  verify_executable "scripts/test.sh" || ((errors++))

  # Verify configs installed
  verify_file_exists ".swiftlint.yml" || ((errors++))
  verify_file_exists ".swiftformat" || ((errors++))
  verify_file_exists ".xcboot/config.yml" || ((errors++))

  # Verify GitHub CI installed
  verify_file_exists ".github/workflows/ci.yml" || ((errors++))
  verify_file_exists ".github/pull_request_template.md" || ((errors++))

  # Verify git hook installed
  verify_file_exists ".git/hooks/pre-commit" || ((errors++))
  verify_executable ".git/hooks/pre-commit" || ((errors++))

  # Verify STATUS.md installed (default)
  verify_file_exists "STATUS.md" || ((errors++))

  if [[ $errors -eq 0 ]]; then
    log_success "Test 1 passed ✓"
    return 0
  else
    log_error "Test 1 failed with $errors error(s)"
    return 1
  fi
}

# Test 2: Template variable replacement
test_template_variables() {
  log_step "Test 2: Template variable replacement"

  local test_dir="$TEST_ROOT/test-template-vars"
  create_mock_project "$test_dir" "MyApp" "17.0" "com.example.MyApp"
  init_git_repo "github"

  run_bootstrap

  local errors=0

  # Check .xcboot/config.yml has correct values
  verify_template_replaced ".xcboot/config.yml" "PROJECT_NAME" "MyApp" || ((errors++))
  verify_template_replaced ".xcboot/config.yml" "DEPLOYMENT_TARGET" "17.0" || ((errors++))

  # Check .swiftlint.yml has project name
  verify_template_replaced ".swiftlint.yml" "PROJECT_NAME" "MyApp" || ((errors++))

  # Verify no unreplaced variables in key files
  verify_no_template_vars ".xcboot/config.yml" || ((errors++))
  verify_no_template_vars ".swiftlint.yml" || ((errors++))

  if [[ $errors -eq 0 ]]; then
    log_success "Test 2 passed ✓"
    return 0
  else
    log_error "Test 2 failed with $errors error(s)"
    return 1
  fi
}

# Test 3: GitLab CI provider detection
test_gitlab_provider() {
  log_step "Test 3: GitLab CI provider detection"

  local test_dir="$TEST_ROOT/test-gitlab"
  create_mock_project "$test_dir" "GitLabApp"
  init_git_repo "gitlab"

  run_bootstrap

  local errors=0

  # Verify GitLab CI files installed
  verify_file_exists ".gitlab-ci.yml" || ((errors++))
  verify_file_exists ".gitlab/merge_request_templates/default.md" || ((errors++))

  # Verify GitHub files NOT installed
  if [[ -f ".github/workflows/ci.yml" ]]; then
    log_error "GitHub CI installed for GitLab project"
    ((errors++))
  else
    log_debug "✓ GitHub CI correctly not installed"
  fi

  if [[ $errors -eq 0 ]]; then
    log_success "Test 3 passed ✓"
    return 0
  else
    log_error "Test 3 failed with $errors error(s)"
    return 1
  fi
}

# Test 4: Bitbucket provider detection
test_bitbucket_provider() {
  log_step "Test 4: Bitbucket provider detection"

  local test_dir="$TEST_ROOT/test-bitbucket"
  create_mock_project "$test_dir" "BitbucketApp"
  init_git_repo "bitbucket"

  run_bootstrap

  local errors=0

  # Verify Bitbucket files installed
  verify_file_exists "bitbucket-pipelines.yml" || ((errors++))
  verify_file_exists "pull_request_template.md" || ((errors++))

  # Verify other CI files NOT installed
  if [[ -f ".github/workflows/ci.yml" ]] || [[ -f ".gitlab-ci.yml" ]]; then
    log_error "Wrong CI provider installed for Bitbucket project"
    ((errors++))
  else
    log_debug "✓ Other CI providers correctly not installed"
  fi

  if [[ $errors -eq 0 ]]; then
    log_success "Test 4 passed ✓"
    return 0
  else
    log_error "Test 4 failed with $errors error(s)"
    return 1
  fi
}

# Test 5: --no-status flag
test_no_status_flag() {
  log_step "Test 5: --no-status flag"

  local test_dir="$TEST_ROOT/test-no-status"
  create_mock_project "$test_dir" "NoStatusApp"
  init_git_repo "github"

  run_bootstrap "--no-status"

  local errors=0

  # Verify STATUS.md NOT installed
  if [[ -f "STATUS.md" ]]; then
    log_error "STATUS.md installed despite --no-status flag"
    ((errors++))
  else
    log_debug "✓ STATUS.md correctly not installed"
  fi

  # Verify other files still installed
  verify_file_exists "scripts/build.sh" || ((errors++))
  verify_file_exists ".xcboot/config.yml" || ((errors++))

  if [[ $errors -eq 0 ]]; then
    log_success "Test 5 passed ✓"
    return 0
  else
    log_error "Test 5 failed with $errors error(s)"
    return 1
  fi
}

# Test 6: --force flag (upgrade)
test_force_flag() {
  log_step "Test 6: --force flag (upgrade)"

  local test_dir="$TEST_ROOT/test-force"
  create_mock_project "$test_dir" "ForceApp"
  init_git_repo "github"

  # First installation
  run_bootstrap

  # Modify a file
  echo "# Modified" >>scripts/build.sh

  # Run again with --force
  run_bootstrap "--force"

  local errors=0

  # Verify file was overwritten (modification should be gone)
  if grep -q "# Modified" scripts/build.sh; then
    log_error "File not overwritten with --force flag"
    ((errors++))
  else
    log_debug "✓ File correctly overwritten with --force"
  fi

  # Verify all files still present
  verify_file_exists "scripts/build.sh" || ((errors++))
  verify_file_exists ".xcboot/config.yml" || ((errors++))

  if [[ $errors -eq 0 ]]; then
    log_success "Test 6 passed ✓"
    return 0
  else
    log_error "Test 6 failed with $errors error(s)"
    return 1
  fi
}

# Test 7: Non-git repository
test_no_git_repo() {
  log_step "Test 7: Non-git repository"

  local test_dir="$TEST_ROOT/test-no-git"
  create_mock_project "$test_dir" "NoGitApp"
  # Don't initialize git repo

  run_bootstrap

  local errors=0

  # Verify scripts still installed
  verify_file_exists "scripts/build.sh" || ((errors++))
  verify_file_exists ".xcboot/config.yml" || ((errors++))

  # Verify git hook NOT installed (no .git directory)
  if [[ -f ".git/hooks/pre-commit" ]]; then
    log_error "Git hook installed for non-git project"
    ((errors++))
  else
    log_debug "✓ Git hook correctly not installed"
  fi

  # Verify CI files NOT installed (no git = no CI)
  if [[ -f ".github/workflows/ci.yml" ]] || [[ -f ".gitlab-ci.yml" ]] || [[ -f "bitbucket-pipelines.yml" ]]; then
    log_error "CI files installed for non-git project"
    ((errors++))
  else
    log_debug "✓ CI files correctly not installed for non-git project"
  fi

  if [[ $errors -eq 0 ]]; then
    log_success "Test 7 passed ✓"
    return 0
  else
    log_error "Test 7 failed with $errors error(s)"
    return 1
  fi
}

# Cleanup test directory
cleanup() {
  if [[ -d $TEST_ROOT ]]; then
    if $KEEP_ARTIFACTS; then
      log_info "Keeping test artifacts: $TEST_ROOT"
    else
      log_debug "Cleaning up test directory: $TEST_ROOT"
      rm -rf "$TEST_ROOT"
      log_debug "Cleanup complete"
    fi
  fi
}

# Main test runner
main() {
  parse_arguments "$@"

  # Show banner
  cat <<EOF

${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${BOLD}     xcboot Integration Test Suite${NC}
${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

EOF

  log_info "xcboot root: $XCBOOT_ROOT"
  log_info "Test root: $TEST_ROOT"
  echo

  # Safety check
  safety_check

  # Create test root
  mkdir -p "$TEST_ROOT"
  log_debug "Created test root: $TEST_ROOT"
  echo

  # Track failures
  local failed=0
  local total=7

  # Run tests
  test_basic_installation || ((failed++))
  echo

  test_template_variables || ((failed++))
  echo

  test_gitlab_provider || ((failed++))
  echo

  test_bitbucket_provider || ((failed++))
  echo

  test_no_status_flag || ((failed++))
  echo

  test_force_flag || ((failed++))
  echo

  test_no_git_repo || ((failed++))
  echo

  # Summary
  echo "========================================="

  if [[ $failed -eq 0 ]]; then
    log_success "All $total tests passed! 🎉"
    cleanup
    exit 0
  else
    log_error "$failed of $total test(s) failed"
    log_warning "Test artifacts preserved at: $TEST_ROOT"
    log_info "Inspect failed tests and run cleanup manually:"
    log_info "  rm -rf $TEST_ROOT"
    exit 1
  fi
}

# Run main
main "$@"
