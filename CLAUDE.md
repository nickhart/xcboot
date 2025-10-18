# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**xcboot** is a bootstrap tool for iOS/Xcode projects that installs GitHub CI, quality tools (SwiftLint, SwiftFormat), helper scripts, and optional MVVM directory structure into existing or new Xcode projects.

**Current Status**: Phase 1 - Core Infrastructure (v0.1.0-dev)

**Key Innovation**: Runs FROM INSIDE an existing Xcode project via a bootstrap script (avoiding directory nesting issues). Users curl the script and it installs tooling into their project.

## Architecture

### Two Modes of Operation

1. **ADOPT Mode** (primary): Bootstrap existing `.xcodeproj` with tooling
   - Detects project metadata via `xcodegen dump`
   - Installs scripts, configs, CI workflow into existing project
   - Optional MVVM directory structure generation

2. **GENERATE Mode**: Create minimal Swift project then bootstrap it
   - Creates minimal UIKit project files
   - Runs `xcodegen` to create `.xcodeproj`
   - Continues with ADOPT mode

### Configuration System

- `.xcboot/config.yml` - System defaults (checked into repo, distributed to users)
- `.xcboot.yml` - User overrides (gitignored, created in user's project)
- Configs are merged at runtime

### Distribution Strategy

Primary distribution is via `bootstrap.sh` downloaded from GitHub raw content:
```bash
curl -fsSL https://raw.githubusercontent.com/nickhart/xcboot/main/bootstrap.sh | bash
```

## Directory Structure (Planned)

```
xcboot/
├── bootstrap.sh              # Main installer script (primary distribution)
├── VERSION                   # Semantic version file
├── Brewfile                  # Development dependencies
├── scripts/                  # Core automation scripts (to be distributed)
│   ├── _helpers.sh          # Shared utility functions
│   ├── build.sh             # Build automation
│   ├── test.sh              # Test automation (unit + UI)
│   ├── lint.sh              # SwiftLint wrapper
│   ├── format.sh            # SwiftFormat wrapper
│   ├── preflight.sh         # Complete local CI check
│   ├── simulator.sh         # Simulator management
│   └── pre-commit.sh        # Git pre-commit hook
├── templates/                # Config file templates (distributed)
│   ├── swiftlint.yml
│   ├── swiftformat
│   ├── project.yml          # XcodeGen config for GENERATE mode
│   ├── simulator.yml        # Test simulator configuration
│   ├── STATUS.md            # STATUS-first documentation template
│   └── github/
│       ├── ci.yml           # GitHub Actions workflow
│       └── pull_request_template.md
├── .xcboot/
│   └── config.yml           # Default configuration
└── docs/                    # Documentation
```

## Key Technical Decisions

### Project Detection via `xcodegen dump`
- Extracts project name, bundle ID, deployment target from existing `.xcodeproj`
- Avoids prompting user for information that already exists
- Works with any Xcode project structure

### Simulator Auto-Detection
- Uses `xcrun simctl list devices available -j` to query available simulators
- Selects best match based on deployment target
- Avoids hardcoded simulator names that break across iOS versions

### STATUS-First Documentation
- Documentation starts with current status, then architecture/vision
- Applied to both this repo's STATUS.md and generated project STATUS.md templates
- Prioritizes actionable information up front

## Implementation Phases

**Phase 1** (CURRENT): Core Infrastructure
- Repository initialization, LICENSE, .gitignore
- Directory structure creation
- VERSION, Brewfile, CONTRIBUTING.md, CHANGELOG.md

**Phase 2**: Bootstrap Script
- `bootstrap.sh` with project detection, config merging
- ADOPT and GENERATE mode implementation
- Simulator auto-detection

**Phase 3**: Core Scripts
- Port automation scripts from SwiftProjectTemplate
- Build, test, lint, format, preflight, simulator, pre-commit

**Phase 4**: Templates
- SwiftLint, SwiftFormat configs
- XcodeGen project template
- GitHub Actions workflow
- PR template

**Phase 5**: Quality & Release
- CI workflows for xcboot itself
- Documentation
- Tag v1.0.0

## Development Workflow

This repository is in early development. When implementing features:

1. Follow the phase sequence in STATUS.md
2. Scripts should be portable shell scripts (bash)
3. Templates use placeholder syntax (e.g., `{{PROJECT_NAME}}`) for bootstrap.sh replacement
4. All distributed files go in `scripts/` or `templates/`
5. Update STATUS.md task checkboxes as work completes

## Testing Strategy (Future)

- xcboot's own CI will test the bootstrap process
- Test against multiple Xcode versions
- Test ADOPT mode with real Xcode projects
- Test GENERATE mode creates valid projects
- Verify simulator auto-detection works across iOS versions

## Related Context

- This project replaces/improves upon SwiftProjectTemplate (template repo approach)
- SwiftProjectTemplate had directory nesting issues and no upgrade path
- xcboot solves this via bootstrap-from-within approach (like fastlane, oh-my-zsh)
