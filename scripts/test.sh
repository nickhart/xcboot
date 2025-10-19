#!/usr/bin/env bash
set -euo pipefail

# Test script for xcboot development
# Tests the bootstrap process and validates xcboot functionality

# shellcheck disable=SC2329  # log_warning unused but kept for consistency

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() {
  echo -e "${BLUE}INFO:${NC} $*"
}

log_success() {
  echo -e "${GREEN}SUCCESS:${NC} $*"
}

# shellcheck disable=SC2329  # log_warning unused but kept for consistency
log_warning() {
  echo -e "${YELLOW}WARNING:${NC} $*"
}

log_error() {
  echo -e "${RED}ERROR:${NC} $*" >&2
}

log_info "xcboot Test Suite"
echo "=================="
echo

# Test 1: Verify all required files exist
test_file_structure() {
  log_info "Test 1: Verifying file structure..."

  local required_files=(
    "VERSION"
    "Brewfile"
    "CHANGELOG.md"
    "CONTRIBUTING.md"
    "templates/default/.xcboot/config.yml"
    "templates/default/scripts/_helpers.sh"
    "templates/default/scripts/build.sh"
    "templates/default/scripts/test.sh"
    "templates/default/scripts/lint.sh"
    "templates/default/scripts/format.sh"
    "templates/default/scripts/preflight.sh"
    "templates/default/scripts/simulator.sh"
    "templates/default/scripts/pre-commit.sh"
    "templates/default/configs/swiftlint.yml"
    "templates/default/configs/swiftformat"
    "templates/default/project.yml"
    "templates/default/STATUS.md"
  )

  local missing_files=()

  for file in "${required_files[@]}"; do
    if [[ ! -f $file ]]; then
      missing_files+=("$file")
    fi
  done

  if [[ ${#missing_files[@]} -gt 0 ]]; then
    log_error "Missing required files:"
    for file in "${missing_files[@]}"; do
      echo "  - $file"
    done
    return 1
  fi

  log_success "All required files present ✓"
  return 0
}

# Test 2: Verify scripts are executable
test_script_permissions() {
  log_info "Test 2: Verifying script permissions..."

  local scripts=(
    "templates/default/scripts/_helpers.sh"
    "templates/default/scripts/build.sh"
    "templates/default/scripts/test.sh"
    "templates/default/scripts/lint.sh"
    "templates/default/scripts/format.sh"
    "templates/default/scripts/preflight.sh"
    "templates/default/scripts/simulator.sh"
    "templates/default/scripts/pre-commit.sh"
  )

  local non_executable=()

  for script in "${scripts[@]}"; do
    if [[ ! -x $script ]]; then
      non_executable+=("$script")
    fi
  done

  if [[ ${#non_executable[@]} -gt 0 ]]; then
    log_error "Non-executable scripts:"
    for script in "${non_executable[@]}"; do
      echo "  - $script"
    done
    return 1
  fi

  log_success "All scripts are executable ✓"
  return 0
}

# Test 3: Validate YAML files
test_yaml_validity() {
  log_info "Test 3: Validating YAML files..."

  if ./scripts/validate.sh >/dev/null 2>&1; then
    log_success "All YAML files valid ✓"
    return 0
  else
    log_error "YAML validation failed"
    return 1
  fi
}

# Test 4: Check VERSION file
test_version_file() {
  log_info "Test 4: Checking VERSION file..."

  if [[ ! -f "VERSION" ]]; then
    log_error "VERSION file not found"
    return 1
  fi

  local version
  version=$(cat VERSION)

  if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid version format: $version (expected semver: X.Y.Z)"
    return 1
  fi

  log_success "VERSION file valid: $version ✓"
  return 0
}

# Test 5: Verify CI configs exist for all providers
test_ci_configs() {
  log_info "Test 5: Checking CI configurations..."

  local ci_files=(
    "templates/default/ci/github/workflows/ci.yml"
    "templates/default/ci/github/pull_request_template.md"
    "templates/default/ci/gitlab/.gitlab-ci.yml"
    "templates/default/ci/gitlab/merge_request_templates/default.md"
    "templates/default/ci/bitbucket/bitbucket-pipelines.yml"
    "templates/default/ci/bitbucket/pull_request_template.md"
  )

  local missing=()

  for file in "${ci_files[@]}"; do
    if [[ ! -f $file ]]; then
      missing+=("$file")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing CI config files:"
    for file in "${missing[@]}"; do
      echo "  - $file"
    done
    return 1
  fi

  log_success "All CI configurations present ✓"
  return 0
}

# Run all tests
main() {
  local failed=0

  test_file_structure || failed=$((failed + 1))
  echo

  test_script_permissions || failed=$((failed + 1))
  echo

  test_yaml_validity || failed=$((failed + 1))
  echo

  test_version_file || failed=$((failed + 1))
  echo

  test_ci_configs || failed=$((failed + 1))
  echo

  echo "========================================="
  if [[ $failed -eq 0 ]]; then
    log_success "All tests passed! 🎉"
    exit 0
  else
    log_error "$failed test(s) failed"
    exit 1
  fi
}

main
