#!/usr/bin/env bash
set -euo pipefail

# Format script for xcboot development
# Runs shfmt on all bash scripts in the repository

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

# Default: check only
FIX=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --fix)
      FIX=true
      shift
      ;;
    --help|-h)
      cat <<EOF
Format Script for xcboot

Runs shfmt to check or fix shell script formatting.

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --fix        Auto-fix formatting issues
  --help       Show this help message

EXAMPLES:
  $0           # Check formatting
  $0 --fix     # Fix formatting issues

EOF
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      echo "Use '$0 --help' for usage information"
      exit 1
      ;;
  esac
done

# Check if shfmt is installed
if ! command -v shfmt >/dev/null 2>&1; then
  log_error "shfmt is not installed"
  log_info "Install with: brew install shfmt"
  exit 1
fi

# Find all .sh files
all_scripts=$(find . -type f -name "*.sh" -not -path "./.git/*" -not -path "./build/*")

if [[ -z "$all_scripts" ]]; then
  log_error "No shell scripts found"
  exit 1
fi

if $FIX; then
  log_info "Formatting all bash scripts with shfmt..."
  echo

  # Format with: 2-space indents, simplify code, binary ops start line
  # -i 2: indent with 2 spaces
  # -s: simplify the code
  # -bn: binary ops like && and | may start a line
  echo "$all_scripts" | xargs shfmt -i 2 -s -bn -w

  log_success "All scripts formatted! 🎨"
else
  log_info "Checking formatting with shfmt..."
  echo

  # Check formatting (returns non-zero if files would be changed)
  if echo "$all_scripts" | xargs shfmt -i 2 -s -bn -d; then
    echo
    log_success "All scripts are properly formatted! ✓"
    exit 0
  else
    echo
    log_warning "Some scripts need formatting"
    log_info "Run './scripts/format.sh --fix' to auto-fix"
    exit 1
  fi
fi
