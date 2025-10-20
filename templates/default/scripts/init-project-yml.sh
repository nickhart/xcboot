#!/usr/bin/env bash
set -euo pipefail

# init-project-yml.sh - Generate project.yml from existing Xcode project
#
# This script intelligently analyzes an existing .xcodeproj and generates
# a project.yml file suitable for XcodeGen.
#
# Usage:
#   ./scripts/init-project-yml.sh [OPTIONS]
#
# Auto-detects:
#   - Project name from .xcodeproj
#   - Test framework (swift-testing vs xctest)
#   - Swift version from .swift-version
#   - Deployment target from pbxproj
#   - Bundle ID root from pbxproj
#
# Prompts interactively for:
#   - Bundle ID root (if not detected)
#   - Development team ID (optional)
#
# Non-interactive mode:
#   Use flags to skip prompts (useful for CI/automation)

# Source helper functions (provides colors and logging)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # _helpers.sh is in same directory, sourcing is safe
source "$SCRIPT_DIR/_helpers.sh"

# Additional logging function (not in _helpers.sh)
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'

log_step() {
  echo -e "${CYAN}${BOLD}→${NC} $*"
}

# Default values
PROJECT_NAME=""
BUNDLE_ID_ROOT=""
DEPLOYMENT_TARGET=""
SWIFT_VERSION=""
TEST_FRAMEWORK=""
DEVELOPMENT_TEAM=""
FORCE_OVERWRITE=false
NON_INTERACTIVE=false

show_help() {
  cat <<EOF
${BOLD}init-project-yml.sh - Generate project.yml from existing Xcode project${NC}

This script analyzes your existing .xcodeproj and generates a project.yml file
suitable for XcodeGen. It auto-detects project settings and provides interactive
prompts for missing information.

${BOLD}USAGE:${NC}
  ./scripts/init-project-yml.sh [OPTIONS]

${BOLD}OPTIONS:${NC}
  --project-name <name>         Override detected project name
  --bundle-id-root <root>       Bundle identifier root (e.g., com.mycompany)
  --deployment-target <version> iOS deployment target (e.g., 18.0)
  --swift-version <version>     Swift version (e.g., 6.2)
  --test-framework <framework>  Test framework: swift-testing or xctest
  --development-team <id>       Development team ID (optional)
  --force                       Overwrite existing project.yml
  --non-interactive             Skip all prompts (use detected/provided values)
  --help                        Show this help message

${BOLD}AUTO-DETECTION:${NC}
  The script automatically detects:
  • Project name from *.xcodeproj directory
  • Test framework by scanning test files for 'import Testing' or 'import XCTest'
  • Swift version from .swift-version file
  • Deployment target from project.pbxproj
  • Bundle ID root from project.pbxproj

${BOLD}EXAMPLES:${NC}
  # Interactive mode with auto-detection
  ./scripts/init-project-yml.sh

  # Non-interactive with all values provided
  ./scripts/init-project-yml.sh --non-interactive --bundle-id-root com.mycompany

  # Override specific values
  ./scripts/init-project-yml.sh --deployment-target 17.0 --test-framework xctest

  # Force overwrite existing project.yml
  ./scripts/init-project-yml.sh --force

${BOLD}NOTES:${NC}
  • Run this from your project root directory
  • Ensure .xcodeproj exists before running
  • Generated project.yml is ready to use with 'xcodegen generate'
  • Review and customize project.yml after generation if needed

EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    --project-name)
      PROJECT_NAME="$2"
      shift 2
      ;;
    --bundle-id-root)
      BUNDLE_ID_ROOT="$2"
      shift 2
      ;;
    --deployment-target)
      DEPLOYMENT_TARGET="$2"
      shift 2
      ;;
    --swift-version)
      SWIFT_VERSION="$2"
      shift 2
      ;;
    --test-framework)
      TEST_FRAMEWORK="$2"
      shift 2
      ;;
    --development-team)
      DEVELOPMENT_TEAM="$2"
      shift 2
      ;;
    --force)
      FORCE_OVERWRITE=true
      shift
      ;;
    --non-interactive)
      NON_INTERACTIVE=true
      shift
      ;;
    --help | -h)
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

# Detect project name from .xcodeproj
detect_project_name() {
  local xcodeproj
  xcodeproj=$(find . -maxdepth 1 -name "*.xcodeproj" -type d | head -1)

  if [[ -n $xcodeproj ]]; then
    basename "$xcodeproj" .xcodeproj
    return 0
  fi

  echo ""
  return 1
}

# Detect bundle ID root from pbxproj
detect_bundle_id_root() {
  local project_name="$1"
  local pbxproj="${project_name}.xcodeproj/project.pbxproj"

  if [[ ! -f $pbxproj ]]; then
    echo ""
    return 1
  fi

  local bundle_id
  bundle_id=$(grep -m 1 "PRODUCT_BUNDLE_IDENTIFIER" "$pbxproj" | sed 's/.*= \(.*\);/\1/' | tr -d ' "' | sed 's/\.[^.]*$//' || echo "")

  # shellcheck disable=SC2016  # Intentional literal string comparison
  if [[ -n $bundle_id && $bundle_id != '$(PRODUCT_BUNDLE_IDENTIFIER)' ]]; then
    echo "$bundle_id"
    return 0
  fi

  echo ""
  return 1
}

# Detect deployment target from pbxproj
detect_deployment_target() {
  local project_name="$1"
  local pbxproj="${project_name}.xcodeproj/project.pbxproj"

  if [[ ! -f $pbxproj ]]; then
    echo "18.0"
    return
  fi

  local target
  target=$(grep -m 1 "IPHONEOS_DEPLOYMENT_TARGET" "$pbxproj" | sed 's/.*= \(.*\);/\1/' | tr -d ' "' || echo "")

  if [[ -n $target ]]; then
    echo "$target"
  else
    echo "18.0"
  fi
}

# Detect Swift version from .swift-version file
detect_swift_version() {
  if [[ -f ".swift-version" ]]; then
    cat .swift-version | tr -d '[:space:]'
    return 0
  fi

  if command -v swift >/dev/null 2>&1; then
    swift --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "6.2"
  else
    echo "6.2"
  fi
}

# Detect test framework by scanning test files
detect_test_framework() {
  local project_name="$1"
  local test_dir="${project_name}Tests"

  if [[ ! -d $test_dir ]]; then
    # Default to swift-testing for new projects
    echo "swift-testing"
    return
  fi

  # Search for import statements in test files
  local has_swift_testing=false
  local has_xctest=false

  while IFS= read -r -d '' file; do
    if grep -q "import Testing" "$file" 2>/dev/null; then
      has_swift_testing=true
    fi
    if grep -q "import XCTest" "$file" 2>/dev/null; then
      has_xctest=true
    fi
  done < <(find "$test_dir" -name "*.swift" -type f -print0 2>/dev/null)

  # If both found, prefer swift-testing (newer)
  if [[ $has_swift_testing == true ]]; then
    echo "swift-testing"
  elif [[ $has_xctest == true ]]; then
    echo "xctest"
  else
    # Default to swift-testing
    echo "swift-testing"
  fi
}

# Prompt for value with default
prompt_with_default() {
  local prompt="$1"
  local default="$2"
  local value=""

  if [[ $NON_INTERACTIVE == true ]]; then
    echo "$default"
    return
  fi

  if [[ ! -t 0 ]]; then
    # Not interactive (piped input)
    echo "$default"
    return
  fi

  echo -n "$prompt [$default]: "
  read -r value

  if [[ -z $value ]]; then
    echo "$default"
  else
    echo "$value"
  fi
}

# Generate project.yml content
generate_project_yml() {
  local project_name="$1"
  local bundle_id_root="$2"
  local deployment_target="$3"
  local swift_version="$4"
  local development_team="$5"

  cat <<EOF
name: $project_name
options:
  bundleIdPrefix: $bundle_id_root
  developmentLanguage: en
  deploymentTarget:
    iOS: "$deployment_target"
  xcodeVersion: "15.0"
  generateEmptyDirectories: true

# packages:
  # Add Swift Package Manager dependencies here when needed
  # Example:
  # Alamofire:
  #   url: https://github.com/Alamofire/Alamofire
  #   majorVersion: 5.8.0

settings:
  base:
    # Swift version
    SWIFT_VERSION: "$swift_version"
    # Development settings
    DEVELOPMENT_TEAM: "$development_team"
    CODE_SIGN_IDENTITY: "Apple Development"
    CODE_SIGN_STYLE: Automatic
    # Build settings
    ENABLE_BITCODE: false
    SUPPORTS_MACCATALYST: false
    # Warning settings
    SWIFT_TREAT_WARNINGS_AS_ERRORS: false
    GCC_TREAT_WARNINGS_AS_ERRORS: false
    # Other settings
    ENABLE_HARDENED_RUNTIME: YES
    ENABLE_USER_SCRIPT_SANDBOXING: YES
    STRING_CATALOG_GENERATE_SYMBOLS: YES
    ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS: YES
    ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor

targets:
  "$project_name":
    type: application
    platform: iOS
    deploymentTarget: "$deployment_target"
    sources:
      - "$project_name"
    resources:
      - "$project_name/Resources"
    info:
      path: "$project_name/Info.plist"
      properties:
        CFBundleDisplayName: "$project_name"
        CFBundleVersion: "1"
        CFBundleShortVersionString: "1.0"
        UILaunchStoryboardName: LaunchScreen
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
          - UIInterfaceOrientationLandscapeLeft
          - UIInterfaceOrientationLandscapeRight
        UISupportedInterfaceOrientations~ipad:
          - UIInterfaceOrientationPortrait
          - UIInterfaceOrientationPortraitUpsideDown
          - UIInterfaceOrientationLandscapeLeft
          - UIInterfaceOrientationLandscapeRight
        UIRequiredDeviceCapabilities:
          - armv7
        LSRequiresIPhoneOS: true
        UIApplicationSceneManifest:
          UIApplicationSupportsMultipleScenes: false
          UISceneConfigurations:
            UIWindowSceneSessionRoleApplication:
              - UISceneConfigurationName: Default Configuration
                UISceneDelegateClassName: \$(PRODUCT_MODULE_NAME).SceneDelegate

  "${project_name}Tests":
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "$deployment_target"
    sources:
      - "${project_name}Tests"
    dependencies:
      - target: "$project_name"

  "${project_name}UITests":
    type: bundle.ui-testing
    platform: iOS
    deploymentTarget: "$deployment_target"
    sources:
      - "${project_name}UITests"
    dependencies:
      - target: "$project_name"

schemes:
  "$project_name":
    build:
      targets:
        "$project_name": all
        "${project_name}Tests": [test]
        "${project_name}UITests": [test]
    run:
      config: Debug
    test:
      config: Debug
      gatherCoverageData: true
      coverageTargets:
        - "$project_name"
      targets:
        - "${project_name}Tests"
        - "${project_name}UITests"
    profile:
      config: Release
    analyze:
      config: Debug
    archive:
      config: Release
EOF
}

main() {
  parse_arguments "$@"

  echo
  log_step "Initializing project.yml generation..."
  echo

  # Check if project.yml already exists
  if [[ -f "project.yml" ]] && [[ $FORCE_OVERWRITE != true ]]; then
    log_error "project.yml already exists"
    log_info "Use --force to overwrite existing file"
    exit 1
  fi

  # Step 1: Auto-detect or use provided project name
  if [[ -z $PROJECT_NAME ]]; then
    log_step "Detecting project name..."
    PROJECT_NAME=$(detect_project_name)
    if [[ -z $PROJECT_NAME ]]; then
      log_error "No Xcode project found in current directory"
      log_info "Make sure you're in a directory with a .xcodeproj file"
      exit 1
    fi
    log_success "Detected project: $PROJECT_NAME"
  else
    log_info "Using provided project name: $PROJECT_NAME"
  fi
  echo

  # Step 2: Auto-detect deployment target
  if [[ -z $DEPLOYMENT_TARGET ]]; then
    log_step "Detecting deployment target..."
    DEPLOYMENT_TARGET=$(detect_deployment_target "$PROJECT_NAME")
    log_success "Detected deployment target: iOS $DEPLOYMENT_TARGET"
  else
    log_info "Using provided deployment target: iOS $DEPLOYMENT_TARGET"
  fi
  echo

  # Step 3: Auto-detect Swift version
  if [[ -z $SWIFT_VERSION ]]; then
    log_step "Detecting Swift version..."
    SWIFT_VERSION=$(detect_swift_version)
    log_success "Detected Swift version: $SWIFT_VERSION"
  else
    log_info "Using provided Swift version: $SWIFT_VERSION"
  fi
  echo

  # Step 4: Auto-detect test framework
  if [[ -z $TEST_FRAMEWORK ]]; then
    log_step "Detecting test framework..."
    TEST_FRAMEWORK=$(detect_test_framework "$PROJECT_NAME")
    log_success "Detected test framework: $TEST_FRAMEWORK"
  else
    log_info "Using provided test framework: $TEST_FRAMEWORK"
  fi
  echo

  # Step 5: Auto-detect or prompt for bundle ID root
  if [[ -z $BUNDLE_ID_ROOT ]]; then
    log_step "Detecting bundle identifier..."
    local detected_bundle_id
    detected_bundle_id=$(detect_bundle_id_root "$PROJECT_NAME")

    if [[ -n $detected_bundle_id ]]; then
      log_success "Detected bundle ID root: $detected_bundle_id"
      BUNDLE_ID_ROOT=$(prompt_with_default "Enter bundle ID root" "$detected_bundle_id")
    else
      log_warning "Could not detect bundle ID from project"
      BUNDLE_ID_ROOT=$(prompt_with_default "Enter bundle ID root" "com.yourcompany")
    fi
  else
    log_info "Using provided bundle ID root: $BUNDLE_ID_ROOT"
  fi
  echo

  # Step 6: Prompt for development team (optional)
  if [[ -z $DEVELOPMENT_TEAM ]]; then
    log_step "Configure development team (optional)..."
    DEVELOPMENT_TEAM=$(prompt_with_default "Enter development team ID (or leave empty)" "")
  fi
  echo

  # Step 7: Generate project.yml
  log_step "Generating project.yml..."
  generate_project_yml "$PROJECT_NAME" "$BUNDLE_ID_ROOT" "$DEPLOYMENT_TARGET" "$SWIFT_VERSION" "$DEVELOPMENT_TEAM" >project.yml
  log_success "Generated project.yml"
  echo

  # Show summary
  log_success "project.yml generation complete!"
  echo
  log_info "Configuration summary:"
  echo "  • Project name: $PROJECT_NAME"
  echo "  • Bundle ID root: $BUNDLE_ID_ROOT"
  echo "  • Deployment target: iOS $DEPLOYMENT_TARGET"
  echo "  • Swift version: $SWIFT_VERSION"
  echo "  • Test framework: $TEST_FRAMEWORK"
  if [[ -n $DEVELOPMENT_TEAM ]]; then
    echo "  • Development team: $DEVELOPMENT_TEAM"
  fi
  echo
  log_info "Next steps:"
  echo "  1. Review project.yml and customize if needed"
  echo "  2. Generate Xcode project: xcodegen generate"
  echo "  3. Open project: open ${PROJECT_NAME}.xcodeproj"
  echo
}

main "$@"
