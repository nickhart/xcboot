#!/usr/bin/env bash
set -euo pipefail

# Lint script for xcboot development
# Runs shellcheck on all bash scripts in the repository

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

log_error() {
  echo -e "${RED}ERROR:${NC} $*" >&2
}

# Check if shellcheck is installed
if ! command -v shellcheck >/dev/null 2>&1; then
  log_error "shellcheck is not installed"
  log_info "Install with: brew install shellcheck"
  exit 1
fi

log_info "Running shellcheck on all bash scripts..."
echo

# Find all .sh files
all_scripts=$(find . -type f -name "*.sh" -not -path "./.git/*" -not -path "./build/*")

if [[ -z "$all_scripts" ]]; then
  log_error "No shell scripts found"
  exit 1
fi

total=0
passed=0
failed=0
failed_files=()

while IFS= read -r script; do
  total=$((total + 1))
  echo -n "Checking $script... "

  if shellcheck "$script"; then
    echo -e "${GREEN}✓${NC}"
    passed=$((passed + 1))
  else
    echo -e "${RED}✗${NC}"
    failed=$((failed + 1))
    failed_files+=("$script")
  fi
done <<< "$all_scripts"

echo
echo "========================================="
log_info "Shellcheck Results:"
echo "  Total scripts: $total"
echo "  Passed: $passed"
echo "  Failed: $failed"

if [[ $failed -gt 0 ]]; then
  echo
  log_error "Failed scripts:"
  for file in "${failed_files[@]}"; do
    echo "  - $file"
  done
  echo
  log_info "Fix issues and run again"
  exit 1
else
  echo
  log_success "All scripts passed shellcheck! 🎉"
  exit 0
fi
