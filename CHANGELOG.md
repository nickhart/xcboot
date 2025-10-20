# Changelog

All notable changes to xcboot will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - TBD

### Added

#### Core Infrastructure
- Initial repository structure with MIT License
- VERSION file (0.1.0)
- Brewfile with development dependencies (shellcheck, shfmt, yq, jq, gh)
- Comprehensive documentation (README, STATUS, CONTRIBUTING, CHANGELOG)
- CLAUDE.md for Claude Code assistance

#### Bootstrap Script
- Intelligent bootstrap installer (`bootstrap.sh`)
- Auto-detection of project name from `.xcodeproj` or `project.yml`
- Auto-detection of git provider (GitHub, GitLab, Bitbucket)
- Auto-detection of deployment target from project.pbxproj
- Auto-detection of Swift version
- Auto-detection of optimal simulator configuration
- Mac architecture detection (arm64/x86_64)
- Bundle ID detection and user prompting
- Template variable replacement system
- Local file support for testing (`XCBOOT_LOCAL_PATH` environment variable)
- Download from GitHub raw URLs for production use
- `--force` flag for upgrading existing installations
- `--no-status` flag to skip STATUS.md generation
- `--structure` flag (reserved for future MVVM support)

#### Automation Scripts (8 scripts)
- `scripts/_helpers.sh` - Shared utility functions with logging
- `scripts/build.sh` - Build for simulator or device with xcodebuild
- `scripts/test.sh` - Run unit and UI tests with coverage support
- `scripts/lint.sh` - SwiftLint wrapper with auto-fix support
- `scripts/format.sh` - SwiftFormat wrapper with auto-fix support
- `scripts/preflight.sh` - Complete pre-push validation (lint + format + build + test)
- `scripts/simulator.sh` - Advanced simulator management with auto-creation
- `scripts/pre-commit.sh` - Git pre-commit hook with formatting and linting

All scripts support `.xcboot.yml` user overrides and `.xcboot/config.yml` system defaults.

#### Configuration System
- Two-tier configuration architecture:
  - `.xcboot/config.yml` - System defaults (committed to repo)
  - `.xcboot.yml` - User overrides (gitignored, optional)
- Consolidated simulator configuration in `.xcboot/config.yml`
- Template variable support in all configuration files

#### Template System
- Extensible template architecture in `templates/default/`
- Template variable replacement: `{{PROJECT_NAME}}`, `{{BUNDLE_ID_ROOT}}`, `{{DEPLOYMENT_TARGET}}`, `{{SWIFT_VERSION}}`, `{{CI_PROVIDER}}`, and simulator variables
- **Brewfile template** - Development dependencies for XcodeGen workflow:
  - xcodegen (required - regenerate .xcodeproj from project.yml)
  - swiftlint, swiftformat (code quality)
  - yq (YAML processing)
  - xcbeautify (prettier build output)
- **.gitignore template** - XcodeGen-optimized:
  - Ignores `*.xcodeproj` and `*.xcworkspace` (generated files)
  - Standard Swift/Xcode ignores (xcuserdata, DerivedData, .build, etc.)
- SwiftLint configuration template with sensible defaults
- SwiftFormat configuration template with sensible defaults
- XcodeGen `project.yml` template
- STATUS.md template for user projects

#### Multi-Provider CI Support
- **GitHub Actions** (full support):
  - Complete workflow with lint, format, build, test jobs
  - Code coverage support
  - Pull request template
- **GitLab CI** (basic support):
  - Calls `./scripts/preflight.sh`
  - Merge request template
- **Bitbucket Pipelines** (basic support):
  - Calls `./scripts/preflight.sh`
  - Pull request template

#### Testing & Quality
- Unit test suite (`./scripts/test.sh`) - 5 tests:
  - File structure validation
  - Script permissions verification
  - YAML validation
  - VERSION file check
  - CI configuration presence
- Integration test suite (`./scripts/integration-test.sh`) - 7 comprehensive tests:
  - Basic installation verification
  - Template variable replacement
  - GitLab CI provider detection
  - Bitbucket provider detection
  - `--no-status` flag behavior
  - `--force` upgrade scenario
  - Non-git repository handling
- GitHub runner support (`$RUNNER_TEMP`) for CI
- Local testing mode with `XCBOOT_LOCAL_PATH`
- Mock Xcode project creation for isolated testing
- Shell script linting with shellcheck
- Shell script formatting with shfmt
- YAML validation with yq

#### CI/CD for xcboot
- GitHub Actions workflow with 5 jobs:
  - Lint (shellcheck)
  - Format (shfmt)
  - Validate (YAML with yq)
  - Test (unit tests)
  - Integration Test (bootstrap scenarios)
- Pull request template

#### Documentation
- README.md - Comprehensive user guide with quick start
- STATUS.md - Development roadmap and current status
- docs/ARCHITECTURE.md - Technical architecture deep dive
- docs/TEMPLATES.md - Template creation guide
- docs/DEVELOPMENT.md - Development workflow guide
- CONTRIBUTING.md - Contribution guidelines

#### Developer Experience
- VSCode workspace configuration:
  - Recommended extensions (YAML, Shell, Markdown, GitHub Actions)
  - Workspace settings optimized for:
    - YAML editing (2-space indent, validation)
    - Shell script development (shellcheck, shfmt integration)
    - Markdown documentation (compact style, 120-char guide)
  - File associations and search exclusions

### Fixed
- Shell script linting: Removed unused variables, quoted variables to prevent word splitting
- Shell script formatting: Consistent indentation and style across all scripts
- Integration tests: Fixed empty string argument handling in bootstrap invocation
- Shellcheck directives: Added for acceptable style warnings (SC1091, SC2001, SC2016, SC2162, SC2181)

[Unreleased]: https://github.com/nickhart/xcboot/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/nickhart/xcboot/releases/tag/v0.1.0
