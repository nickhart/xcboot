# xcboot - Bootstrap Tool for iOS Projects

**STATUS**: Repository initialized, ready for implementation (v0.1.0-dev)

---

## What This Is

**xcboot** is a professional bootstrap tool for iOS/Xcode projects. It adds GitHub CI, quality tools (SwiftLint, SwiftFormat), helper scripts, and optional MVVM directory structure to existing or new Xcode projects.

**Key Innovation**: Unlike template repositories, xcboot runs FROM INSIDE your existing Xcode project via a bootstrap script (like fastlane, oh-my-zsh). This solves the directory nesting problem and enables upgrade paths.

## Quick Start (Planned)

```bash
# From inside your Xcode project directory:
curl -fsSL https://raw.githubusercontent.com/nickhart/xcboot/main/bootstrap.sh | bash

# Or with options:
curl -fsSL https://raw.githubusercontent.com/nickhart/xcboot/main/bootstrap.sh | bash -s -- --structure mvvm --test-framework swift-testing
```

## Architecture

### Two Modes

1. **ADOPT Mode** (primary): Bootstrap an existing `.xcodeproj` with tooling
   - Detects project name via `xcodegen dump`
   - Installs scripts, configs, CI workflow
   - Optional: Creates MVVM directory structure
   - Optional: Generates STATUS.md (default: true)

2. **GENERATE Mode**: Create minimal Swift project + bootstrap it
   - Creates minimal UIKit project files
   - Runs xcodegen to create `.xcodeproj`
   - Then runs ADOPT mode

### Config System

- `.xcboot/config.yml` - System defaults (checked into repo)
- `.xcboot.yml` - User overrides (gitignored, optional)
- Merge strategy for flexibility

### Distribution

- **Primary**: Bootstrap script via GitHub raw content
- **Secondary**: GitHub Releases with tarball downloads
- **Future**: Homebrew formula (`brew install xcboot`)

## Implementation Plan

### Phase 1: Core Infrastructure ✅ CURRENT

- [x] Initialize repository
- [x] Add MIT License
- [x] Add Swift .gitignore
- [x] Create initial README.md
- [ ] Create comprehensive README.md (STATUS first structure)
- [ ] Create VERSION file (0.1.0)
- [ ] Create Brewfile
- [ ] Create directory structure (scripts/, templates/, .xcboot/, docs/)
- [ ] Create CONTRIBUTING.md
- [ ] Create CHANGELOG.md

### Phase 2: Bootstrap Script

- [ ] Create bootstrap.sh installer script
  - [ ] Project detection via `xcodegen dump`
  - [ ] Simulator auto-detection via `xcrun simctl list`
  - [ ] Download and extract from GitHub releases
  - [ ] Config file merging logic
  - [ ] ADOPT mode implementation
  - [ ] GENERATE mode implementation
  - [ ] STATUS.md generation (default: true)

### Phase 3: Core Scripts (Port from SwiftProjectTemplate)

- [ ] scripts/_helpers.sh - Shared utility functions
- [ ] scripts/build.sh - Build automation
- [ ] scripts/test.sh - Test automation (unit + UI)
- [ ] scripts/lint.sh - SwiftLint wrapper
- [ ] scripts/format.sh - SwiftFormat wrapper
- [ ] scripts/preflight.sh - Complete local CI check
- [ ] scripts/simulator.sh - Simulator management
- [ ] scripts/pre-commit.sh - Git pre-commit hook

### Phase 4: Templates

- [ ] templates/swiftlint.yml - SwiftLint configuration
- [ ] templates/swiftformat - SwiftFormat configuration
- [ ] templates/project.yml - XcodeGen config (for GENERATE mode)
- [ ] templates/simulator.yml - Test simulator configuration
- [ ] templates/github/ci.yml - GitHub Actions workflow
- [ ] templates/github/pull_request_template.md - PR template
- [ ] templates/STATUS.md - STATUS first documentation template
- [ ] .xcboot/config.yml - Default configuration

### Phase 5: Quality & Release

- [ ] .github/workflows/ci.yml - CI for xcboot itself
- [ ] .github/workflows/release.yml - Automated releases
- [ ] Documentation (installation, usage, architecture)
- [ ] Example usage in docs/
- [ ] Tag v1.0.0

## Key Differences from SwiftProjectTemplate

### SwiftProjectTemplate Issues

- ❌ Directory nesting when creating Xcode projects
- ❌ No upgrade path
- ❌ Template-first workflow (not Xcode-first)
- ❌ Must clone entire repo
- ❌ Placeholder files checked into repo

### xcboot Solutions

- ✅ Bootstrap from inside existing project (no nesting)
- ✅ Re-run with `--force` to upgrade
- ✅ Xcode-first workflow (primary use case)
- ✅ Distributed via single bootstrap script
- ✅ Templates live in xcboot repo, not user's repo
- ✅ Eventually: Homebrew installation

## Technical Design Decisions

### Why Bootstrap Script Over Template Repo?

1. **Solves Nesting Problem**: Xcode creates `MyApp/MyApp/MyApp.xcodeproj` when saving into cloned template
2. **Upgrade Path**: Re-run bootstrap script to get latest configs/scripts
3. **Better UX**: One curl command vs clone + rename + configure
4. **Xcode-First**: Create Xcode project first, then adopt tooling

### Why xcodegen dump?

- Extracts project name, bundle ID, deployment target from existing `.xcodeproj`
- No need to ask user for info that already exists
- Works with any Xcode project structure

### Why Simulator Auto-Detection?

- Hardcoded simulator names break (`"iPhone 16 Pro"` might not exist)
- Deployment targets vary (iOS 15, 16, 17, 18)
- `xcrun simctl list devices available -j` provides JSON we can parse
- Select best match automatically

### Why STATUS First Documentation?

- Immediate clarity on project state
- Actionable information up front
- Marketing/vision at top
- Details below for those who need them
- Works for both README and generated project docs

## Directory Structure

```
xcboot/
├── bootstrap.sh              # Main installer (curl endpoint)
├── README.md                 # Public-facing documentation
├── STATUS.md                 # This file - current status + plan
├── VERSION                   # Semantic version (0.1.0)
├── LICENSE                   # MIT
├── .gitignore               # Swift .gitignore
├── Brewfile                  # Development dependencies
├── CHANGELOG.md              # Version history
├── CONTRIBUTING.md           # Contribution guidelines
├── scripts/                  # Core automation scripts
│   ├── _helpers.sh
│   ├── build.sh
│   ├── test.sh
│   ├── lint.sh
│   ├── format.sh
│   ├── preflight.sh
│   ├── simulator.sh
│   └── pre-commit.sh
├── templates/                # Config file templates
│   ├── swiftlint.yml
│   ├── swiftformat
│   ├── project.yml
│   ├── simulator.yml
│   ├── STATUS.md
│   └── github/
│       ├── ci.yml
│       └── pull_request_template.md
├── .xcboot/                  # Default configuration
│   └── config.yml
├── docs/                     # Additional documentation
│   ├── installation.md
│   ├── usage.md
│   ├── architecture.md
│   └── migration.md
└── .github/
    └── workflows/
        ├── ci.yml            # CI for xcboot itself
        └── release.yml       # Automated releases
```

## Configuration File Format

### .xcboot/config.yml (System Defaults)

```yaml
# xcboot system configuration
version: "1.0"

project:
  # Auto-detected from .xcodeproj
  name: null
  bundle_id_root: null
  deployment_target: null
  swift_version: null

structure:
  # mvvm, clean, or none
  type: mvvm
  # Generate STATUS.md in project root
  generate_status: true

simulators:
  # Auto-detected from xcrun simctl
  tests:
    device: null
    os: null
  ui_tests:
    device: null
    os: null

tools:
  swiftlint: true
  swiftformat: true
  xcodegen: true
  pre_commit_hooks: true

github:
  ci_workflow: true
  pr_template: true
```

### .xcboot.yml (User Overrides, Optional)

```yaml
# User overrides - gitignored
structure:
  type: clean
  generate_status: false

simulators:
  tests:
    device: "iPhone 15 Pro"
    os: "17.5"
```

## Bootstrap Flow

### ADOPT Mode (Existing Project)

1. Detect `.xcodeproj` in current directory
2. Run `xcodegen dump` to extract project info
3. Query `xcrun simctl list devices available -j` for simulators
4. Download xcboot from GitHub release
5. Install scripts/ to project
6. Install templates/ to project (with placeholders replaced)
7. Create `.xcboot/config.yml` with detected values
8. Optionally create directory structure
9. Optionally generate STATUS.md
10. Install git hooks
11. Run `./scripts/preflight.sh` to verify

### GENERATE Mode (New Project)

1. Prompt for project name, bundle ID, deployment target
2. Create minimal Swift files (AppDelegate, SceneDelegate, ViewController)
3. Create test target files
4. Generate project.yml
5. Run `xcodegen generate`
6. Switch to ADOPT mode
7. Continue with steps 3-11 above

## Upgrade Path

```bash
# Re-run bootstrap script with --force
curl -fsSL https://raw.githubusercontent.com/nickhart/xcboot/main/bootstrap.sh | bash -s -- --force

# This will:
# - Update all scripts to latest version
# - Update templates (preserving user customizations)
# - Update .xcboot/config.yml (merging with .xcboot.yml)
# - NOT overwrite user code or tests
```

## Examples

### Bootstrap Existing Xcode Project

```bash
cd ~/Developer/MyAwesomeApp
curl -fsSL https://raw.githubusercontent.com/nickhart/xcboot/main/bootstrap.sh | bash

# Output:
# 🔍 Detected Xcode project: MyAwesomeApp.xcodeproj
# 📦 Installing xcboot v1.0.0...
# 🏗️  Creating MVVM directory structure...
# ✅ Bootstrap complete!
#
# Next steps:
#   ./scripts/build.sh       # Build your project
#   ./scripts/test.sh        # Run tests
#   ./scripts/preflight.sh   # Complete quality check
```

### Generate New Project

```bash
cd ~/Developer
mkdir MyNewApp && cd MyNewApp
curl -fsSL https://raw.githubusercontent.com/nickhart/xcboot/main/bootstrap.sh | bash -s -- --generate

# Prompts:
# Project name: MyNewApp
# Bundle ID root (com.yourcompany): com.example
# Deployment target (18.0): 17.0
# Swift version (6.2): 5.10
# Test framework (swift-testing/xctest): swift-testing
#
# Output:
# 🏗️  Generating minimal Swift project...
# 📦 Installing xcboot v1.0.0...
# ✅ Bootstrap complete!
```

### Custom Structure

```bash
curl -fsSL https://raw.githubusercontent.com/nickhart/xcboot/main/bootstrap.sh | bash -s -- --structure clean --no-status
```

## Next Steps for Development

### Immediate (Phase 1)

1. Create VERSION file (0.1.0)
2. Create comprehensive README.md
3. Port Brewfile from SwiftProjectTemplate
4. Create directory structure
5. Create CONTRIBUTING.md and CHANGELOG.md

### Short Term (Phase 2-3)

6. Implement bootstrap.sh with project detection
7. Port all scripts from SwiftProjectTemplate
8. Create all templates
9. Implement simulator auto-detection

### Medium Term (Phase 4-5)

10. Create CI workflows for xcboot itself
11. Add comprehensive documentation
12. Create example projects
13. Tag v1.0.0 release

### Long Term

14. Create Homebrew formula
15. Add telemetry (opt-in)
16. Support CocoaPods projects
17. Support Swift Package Manager projects
18. IDE plugins (Xcode extension?)

## Contributing

Not yet accepting contributions until v1.0.0 is released and architecture is stable.

## License

MIT License - see LICENSE file

---

**Last Updated**: 2025-10-18
**Current Phase**: Phase 1 - Core Infrastructure
**Next Milestone**: v1.0.0
