#!/usr/bin/env bash
set -euo pipefail

# Validate script for xcboot development
# Validates YAML files in templates/

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

log_warning() {
  echo -e "${YELLOW}WARNING:${NC} $*"
}

log_error() {
  echo -e "${RED}ERROR:${NC} $*" >&2
}

# Check if yq is installed
if ! command -v yq >/dev/null 2>&1; then
  log_error "yq is not installed"
  log_info "Install with: brew install yq"
  exit 1
fi

log_info "Validating YAML files in templates/..."
echo

# Find all YAML files in templates (excluding .DS_Store, etc.)
yaml_files=$(find templates -type f \( -name "*.yml" -o -name "*.yaml" \) -not -path "*/.*")

if [[ -z $yaml_files ]]; then
  log_warning "No YAML files found in templates/"
  exit 0
fi

total=0
passed=0
failed=0
failed_files=()

while IFS= read -r file; do
  total=$((total + 1))
  echo -n "Validating $file... "

  # Try to parse the YAML file with yq
  if yq eval '.' "$file" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
    passed=$((passed + 1))
  else
    echo -e "${RED}✗${NC}"
    failed=$((failed + 1))
    failed_files+=("$file")

    # Show the error
    log_error "YAML syntax error in $file:"
    yq eval '.' "$file" 2>&1 || true
    echo
  fi
done <<<"$yaml_files"

echo
echo "========================================="
log_info "YAML Validation Results:"
echo "  Total files: $total"
echo "  Valid: $passed"
echo "  Invalid: $failed"

if [[ $failed -gt 0 ]]; then
  echo
  log_error "Invalid YAML files:"
  for file in "${failed_files[@]}"; do
    echo "  - $file"
  done
  echo
  log_info "Fix YAML syntax errors and run again"
  exit 1
else
  echo
  log_success "All YAML files are valid! 🎉"
  exit 0
fi
