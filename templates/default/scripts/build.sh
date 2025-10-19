#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2001,SC2005,SC2155,SC2162  # Style preferences acceptable
set -euo pipefail

# Build script for xcboot projects
# Supports building for simulator and device with various configurations

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Source helper functions
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Default values
BUILD_FOR_DEVICE=false
CONFIGURATION="Debug"
CLEAN_BUILD=false
VERBOSE=false

show_help() {
  cat <<EOF
Build Script

Builds the iOS project for simulator or device with various configuration options.

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --device                 Build for device (default: simulator)
  --release                Build in Release configuration (default: Debug)
  --clean                  Clean build folder before building
  --verbose                Show verbose build output
  --help                   Show this help message

EXAMPLES:
  $0                       # Build for simulator in Debug
  $0 --device              # Build for device in Debug
  $0 --release             # Build for simulator in Release
  $0 --device --release    # Build for device in Release
  $0 --clean --verbose     # Clean build with verbose output

REQUIREMENTS:
  - Xcode and xcodebuild
  - Valid .xcodeproj file (run 'xcodegen' if needed)
  - For device builds: valid development team and certificates

EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    --device)
      BUILD_FOR_DEVICE=true
      shift
      ;;
    --release)
      CONFIGURATION="Release"
      shift
      ;;
    --clean)
      CLEAN_BUILD=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help | -h)
      show_help
      exit 0
      ;;
    -*)
      log_error "Unknown option: $1"
      echo "Use '$0 --help' for usage information"
      exit 1
      ;;
    *)
      log_error "Unexpected argument: $1"
      echo "Use '$0 --help' for usage information"
      exit 1
      ;;
    esac
  done
}

get_project_info() {
  if [[ -f "project.yml" ]]; then
    if command_exists yq; then
      PROJECT_NAME=$(yq eval '.name' project.yml)
      DEPLOYMENT_TARGET=$(yq eval '.options.deploymentTarget.iOS' project.yml)
    else
      log_error "yq is required to read project configuration"
      log_info "Install with: brew install yq"
      exit 1
    fi
  else
    log_error "project.yml not found"
    log_info "Run './scripts/setup.sh' first to configure the project"
    exit 1
  fi

  if [[ $PROJECT_NAME == "null" || -z $PROJECT_NAME ]]; then
    log_error "Could not determine project name from project.yml"
    exit 1
  fi
}

determine_destination() {
  if $BUILD_FOR_DEVICE; then
    echo "generic/platform=iOS"
  else
    local simulator_name=""
    local simulator_arch=""

    # Try to get simulator from .xcboot.yml or .xcboot/config.yml
    local config_file=""
    if [[ -f ".xcboot.yml" ]]; then
      config_file=".xcboot.yml"
    elif [[ -f ".xcboot/config.yml" ]]; then
      config_file=".xcboot/config.yml"
    fi

    if [[ -n $config_file ]] && command_exists yq; then
      simulator_name=$(yq '.simulators.tests.device' "$config_file" 2>/dev/null || echo "")
      simulator_arch=$(yq '.simulators.tests.arch' "$config_file" 2>/dev/null || echo "")
      if [[ $simulator_name == "null" || -z $simulator_name ]]; then
        simulator_name=""
      fi
      if [[ $simulator_arch == "null" || -z $simulator_arch ]]; then
        simulator_arch=""
      fi
    fi

    # Fallback to hardcoded defaults based on deployment target
    if [[ -z $simulator_name ]]; then
      simulator_name="iPhone 16 Pro"

      if [[ $DEPLOYMENT_TARGET != "null" && -n $DEPLOYMENT_TARGET ]]; then
        local major_version
        major_version=$(echo "$DEPLOYMENT_TARGET" | cut -d'.' -f1)

        if [[ $major_version -lt "17" ]]; then
          simulator_name="iPhone 15 Pro"
        fi
      fi
    fi

    # Default architecture if not specified
    if [[ -z $simulator_arch ]]; then
      # Auto-detect Mac architecture
      if [[ "$(uname -m)" == "arm64" ]]; then
        simulator_arch="arm64"
      else
        simulator_arch="x86_64"
      fi
    fi

    # Validate simulator exists and suggest alternatives if not
    if ! validate_simulator_exists "$simulator_name"; then
      log_warning "Simulator '$simulator_name' not found"

      # Try to find any available iPhone simulator
      local available_sim
      available_sim=$(find_available_iphone_simulator)

      if [[ -n $available_sim ]]; then
        log_info "Using available simulator: $available_sim"
        simulator_name="$available_sim"
      else
        log_error "No iPhone simulators found. Please install iOS Simulator or run:"
        log_info "  ./scripts/simulator.sh list"
        log_info '  ./scripts/simulator.sh config-tests "<device-name>"'
        exit 1
      fi
    fi

    echo "platform=iOS Simulator,arch=$simulator_arch,name=$simulator_name"
  fi
}

validate_simulator_exists() {
  local sim_name="$1"
  xcrun simctl list devices available 2>/dev/null | grep -q "$sim_name"
}

find_available_iphone_simulator() {
  # Find first available iPhone simulator
  xcrun simctl list devices available 2>/dev/null \
    | grep "iPhone" \
    | head -1 \
    | sed 's/^[[:space:]]*//' \
    | sed 's/ (.*$//'
}

check_project_file() {
  local xcodeproj_path="${PROJECT_NAME}.xcodeproj"

  if [[ ! -d $xcodeproj_path ]]; then
    log_error "Xcode project not found: $xcodeproj_path"
    log_info "Generate it with: xcodegen"
    exit 1
  fi

  # Validate project can be read
  if ! xcodebuild -list -project "$xcodeproj_path" >/dev/null 2>&1; then
    log_error "Xcode project appears to be corrupted: $xcodeproj_path"
    log_info "Regenerate it with: rm -rf '$xcodeproj_path' && xcodegen"
    exit 1
  fi
}

perform_clean_build() {
  if $CLEAN_BUILD; then
    log_info "Cleaning build folder..."

    xcodebuild clean \
      -project "${PROJECT_NAME}.xcodeproj" \
      -scheme "$PROJECT_NAME" \
      -configuration "$CONFIGURATION"

    log_success "Clean completed"
  fi
}

build_project() {
  local destination
  destination=$(determine_destination)

  local build_type
  if $BUILD_FOR_DEVICE; then
    build_type="device"
  else
    build_type="simulator"
  fi

  log_info "Building $PROJECT_NAME for $build_type ($CONFIGURATION configuration)..."
  log_info "Destination: $destination"

  # Prepare build arguments
  local build_args=(
    "build"
    "-project" "${PROJECT_NAME}.xcodeproj"
    "-scheme" "$PROJECT_NAME"
    "-destination" "$destination"
    "-configuration" "$CONFIGURATION"
  )

  # Add device-specific settings
  if $BUILD_FOR_DEVICE; then
    build_args+=(
      "CODE_SIGNING_REQUIRED=YES"
      "CODE_SIGNING_ALLOWED=YES"
    )
  else
    build_args+=(
      "ONLY_ACTIVE_ARCH=YES"
      "CODE_SIGNING_REQUIRED=NO"
      "CODE_SIGNING_ALLOWED=NO"
    )
  fi

  # Log verbose mode if enabled
  if $VERBOSE; then
    log_info "Running with verbose output..."
  fi

  # Execute build
  local start_time
  start_time=$(date +%s)

  if $VERBOSE; then
    xcodebuild "${build_args[@]}"
  else
    if command_exists xcbeautify; then
      xcodebuild "${build_args[@]}" | xcbeautify
    else
      xcodebuild "${build_args[@]}"
    fi
  fi

  local end_time duration
  end_time=$(date +%s)
  duration=$((end_time - start_time))

  log_success "Build completed successfully in ${duration}s"
}

show_build_artifacts() {
  log_info "Build artifacts:"

  # Find build products
  local build_dir="build/$CONFIGURATION"
  if $BUILD_FOR_DEVICE; then
    build_dir="${build_dir}-iphoneos"
  else
    build_dir="${build_dir}-iphonesimulator"
  fi

  if [[ -d $build_dir ]]; then
    local app_path="${build_dir}/${PROJECT_NAME}.app"
    if [[ -d $app_path ]]; then
      echo "  📱 App: $app_path"

      # Show app size
      local app_size
      app_size=$(du -sh "$app_path" 2>/dev/null | cut -f1 || echo "unknown")
      echo "  📦 Size: $app_size"
    fi
  else
    log_info "Build artifacts location not found (may be in DerivedData)"
  fi
}

display_next_steps() {
  echo
  log_success "🎉 Build completed!"

  if $BUILD_FOR_DEVICE; then
    log_info "Device build ready for:"
    echo "  • Archive and distribute"
    echo "  • Install on connected device"
    echo "  • TestFlight upload"
  else
    log_info "Simulator build ready for:"
    echo "  • Run in Xcode (Cmd+R)"
    echo "  • Install on simulator"
    echo "  • Testing with './scripts/test.sh'"
  fi

  echo
  log_info "Next steps:"
  echo "  • Test: ./scripts/test.sh"
  echo "  • Lint: ./scripts/lint.sh"
  echo "  • Full check: ./scripts/preflight.sh"
}

# Main execution
main() {
  log_info "Project Build Script"
  echo

  parse_arguments "$@"
  check_required_tools xcodebuild
  get_project_info
  check_project_file
  perform_clean_build
  build_project
  show_build_artifacts
  display_next_steps
}

# Run main function with all arguments
main "$@"
