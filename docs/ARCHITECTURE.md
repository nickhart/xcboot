# xcboot Architecture

This document provides a detailed overview of xcboot's architecture, design decisions, and how all the pieces fit together.

## Design Philosophy

xcboot follows these core principles:

1. **Zero Configuration** - Works out of the box with intelligent defaults
2. **Convention over Configuration** - Sensible defaults that can be overridden
3. **Bootstrap from Within** - Runs inside the target project (like fastlane)
4. **Multi-Provider Support** - Works with GitHub, GitLab, and Bitbucket
5. **Template-Based** - Extensible template system for different project types
6. **Developer Experience** - Fast, simple, predictable

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     bootstrap.sh                         │
│  (Single entry point - downloads from GitHub)            │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │   Detection Phase     │
         │  • Project name       │
         │  • Git provider       │
         │  • Deployment target  │
         │  • Swift version      │
         │  • Optimal simulator  │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  Installation Phase   │
         │  • Download templates │
         │  • Replace variables  │
         │  • Install files      │
         │  • Set permissions    │
         │  • Install git hooks  │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │   User Project        │
         │  ./scripts/           │
         │  .xcboot/config.yml   │
         │  .swiftlint.yml       │
         │  .github/workflows/   │
         │  .git/hooks/          │
         └───────────────────────┘
```

## Directory Structure

### xcboot Repository

```
xcboot/
├── bootstrap.sh              # Main entry point (curl | bash)
├── VERSION                   # Semantic version
├── Brewfile                  # Dev dependencies
├── CHANGELOG.md              # Release notes
├── CONTRIBUTING.md           # Contribution guide
├── CLAUDE.md                 # Claude Code assistance
│
├── scripts/                  # xcboot development scripts
│   ├── lint.sh              # Lint xcboot's shell scripts
│   ├── format.sh            # Format xcboot's shell scripts
│   ├── validate.sh          # Validate YAML templates
│   └── test.sh              # Test xcboot functionality
│
├── templates/
│   └── default/             # Default template (extensible)
│       ├── scripts/         # User project scripts
│       │   ├── _helpers.sh
│       │   ├── build.sh
│       │   ├── test.sh
│       │   ├── lint.sh
│       │   ├── format.sh
│       │   ├── preflight.sh
│       │   ├── simulator.sh
│       │   └── pre-commit.sh
│       │
│       ├── configs/         # Configuration files
│       │   ├── swiftlint.yml
│       │   └── swiftformat
│       │
│       ├── ci/              # CI configurations
│       │   ├── github/
│       │   │   ├── workflows/ci.yml
│       │   │   └── pull_request_template.md
│       │   ├── gitlab/
│       │   │   ├── .gitlab-ci.yml
│       │   │   └── merge_request_templates/default.md
│       │   └── bitbucket/
│       │       ├── bitbucket-pipelines.yml
│       │       └── pull_request_template.md
│       │
│       ├── .xcboot/
│       │   └── config.yml   # System config template
│       │
│       ├── project.yml      # XcodeGen project template
│       └── STATUS.md        # Status documentation template
│
└── .github/
    └── workflows/
        └── ci.yml           # CI for xcboot itself
```

### User Project After Installation

```
MyApp/
├── MyApp.xcodeproj/
│
├── scripts/                 # Installed by xcboot
│   ├── _helpers.sh
│   ├── build.sh
│   ├── test.sh
│   ├── lint.sh
│   ├── format.sh
│   ├── preflight.sh
│   ├── simulator.sh
│   └── pre-commit.sh
│
├── .xcboot/
│   └── config.yml          # System defaults (committed)
│
├── .xcboot.yml             # User overrides (gitignored)
│
├── Brewfile                # Development dependencies
├── .gitignore              # XcodeGen-optimized (ignores *.xcodeproj)
├── .swiftlint.yml          # SwiftLint config
├── .swiftformat            # SwiftFormat config
│
├── .github/                # GitHub Actions (if GitHub detected)
│   ├── workflows/
│   │   └── ci.yml
│   └── pull_request_template.md
│
└── .git/
    └── hooks/
        └── pre-commit      # xcboot git hook
```

## Template System

### Template Variables

Templates use `{{VARIABLE}}` syntax for replacement:

| Variable | Example | Source |
|----------|---------|--------|
| `{{PROJECT_NAME}}` | `MyApp` | .xcodeproj name |
| `{{BUNDLE_ID_ROOT}}` | `com.mycompany` | User prompt / detection |
| `{{DEPLOYMENT_TARGET}}` | `18.0` | project.pbxproj |
| `{{SWIFT_VERSION}}` | `6.2` | `swift --version` |
| `{{CI_PROVIDER}}` | `github` | `git remote get-url origin` |
| `{{SIMULATOR_TESTS_NAME}}` | `xcboot-test-sim` | Generated |
| `{{SIMULATOR_TESTS_DEVICE}}` | `iPhone 16 Pro` | Based on deployment target |
| `{{SIMULATOR_TESTS_OS}}` | `18-0` | Based on deployment target |
| `{{SIMULATOR_TESTS_ARCH}}` | `arm64` | Mac architecture |
| `{{SIMULATOR_UI_TESTS_*}}` | Same as above | For UI tests |

### Variable Replacement

Replacement happens in `bootstrap.sh`:

```bash
replace_variables() {
  local content="$1"
  # ... variables ...

  content="${content//\{\{PROJECT_NAME\}\}/$project_name}"
  content="${content//\{\{BUNDLE_ID_ROOT\}\}/$bundle_id_root}"
  # ... etc

  echo "$content"
}
```

This uses bash string replacement for simplicity and speed.

### Adding New Templates

To create a new template (e.g., `swiftui`):

1. Create `templates/swiftui/` directory
2. Copy structure from `templates/default/`
3. Customize scripts/configs for SwiftUI projects
4. Use template variables where needed
5. Test with `./bootstrap.sh --template swiftui`

## Configuration System

### Two-Tier Configuration

xcboot uses a two-tier configuration system:

1. **System Config** (`.xcboot/config.yml`)
   - Committed to git
   - Shared across team
   - Installed by bootstrap.sh
   - Contains detected project settings

2. **User Overrides** (`.xcboot.yml`)
   - Gitignored (local only)
   - Optional
   - Overrides system config
   - Developer preferences

### Configuration Hierarchy

```
User preferences (.xcboot.yml)
        ↓ (overrides)
System defaults (.xcboot/config.yml)
        ↓ (overrides)
Script built-in defaults
```

### Reading Configuration

Scripts use this pattern (from `_helpers.sh`):

```bash
get_config_value() {
  local key="$1"
  local default="$2"

  # Try user config first
  if [[ -f ".xcboot.yml" ]]; then
    local value=$(yq eval "$key" .xcboot.yml 2>/dev/null || echo "")
    if [[ -n "$value" && "$value" != "null" ]]; then
      echo "$value"
      return
    fi
  fi

  # Fall back to system config
  if [[ -f ".xcboot/config.yml" ]]; then
    local value=$(yq eval "$key" .xcboot/config.yml 2>/dev/null || echo "")
    if [[ -n "$value" && "$value" != "null" ]]; then
      echo "$value"
      return
    fi
  fi

  # Use default
  echo "$default"
}
```

## Detection Phase

### Project Name Detection

1. Look for `*.xcodeproj` in current directory
2. Fall back to `yq eval '.name' project.yml` if using xcodegen
3. Error if nothing found

### Git Provider Detection

1. Get remote URL: `git remote get-url origin`
2. Match against patterns:
   - `*github.com*` → `github`
   - `*gitlab.com*` → `gitlab`
   - `*bitbucket.*` → `bitbucket`
3. Default to `github` if no match

### Deployment Target Detection

1. Try project.pbxproj: `grep IPHONEOS_DEPLOYMENT_TARGET`
2. Fall back to project.yml: `yq eval '.options.deploymentTarget.iOS'`
3. Default to `18.0`

### Swift Version Detection

1. Run `swift --version | grep -oE '[0-9]+\.[0-9]+' | head -1`
2. Default to `6.2`

### Simulator Detection

Based on deployment target major version:

| iOS Version | Device | OS |
|-------------|--------|----|
| 18.x | iPhone 16 Pro | 18-0 |
| 17.x | iPhone 15 Pro | 17-5 |
| 16.x | iPhone 15 Pro | 16-4 |

Architecture detected from `uname -m` (arm64 or x86_64).

## Installation Phase

### File Installation Process

1. **Download** from GitHub raw URL
   ```bash
   curl -fsSL "https://raw.githubusercontent.com/nickhart/xcboot/main/templates/default/$file"
   ```

2. **Replace variables** using bash string replacement

3. **Check existing files**
   - Skip if exists (unless `--force`)
   - Create parent directories if needed

4. **Write file** to destination

5. **Set permissions**
   - Scripts: `chmod +x`
   - Configs: default permissions

### CI-Specific Installation

Based on detected provider:

- **GitHub**: Install `.github/workflows/ci.yml` + PR template
- **GitLab**: Install `.gitlab-ci.yml` + MR template
- **Bitbucket**: Install `bitbucket-pipelines.yml` + PR template

### Git Hooks Installation

Creates `.git/hooks/pre-commit`:

```bash
#!/usr/bin/env bash
if [[ -f "./scripts/pre-commit.sh" ]]; then
  ./scripts/pre-commit.sh
else
  echo "Warning: scripts/pre-commit.sh not found"
  exit 0
fi
```

## Script Architecture

### Helper Functions (`_helpers.sh`)

Shared functions for all scripts:

- Logging (info, success, warning, error)
- Configuration reading
- Project detection
- Simulator management

### Script Dependencies

```
build.sh
  ↓ sources
_helpers.sh ← test.sh
  ↓ sources
_helpers.sh ← lint.sh
  ↓ sources
_helpers.sh ← format.sh
  ↓ sources
_helpers.sh
  ↓ sources
_helpers.sh ← simulator.sh
  ↓ sources
_helpers.sh

preflight.sh
  ↓ calls
lint.sh → format.sh → build.sh → test.sh
```

### Simulator Management

Simulators are managed via `.xcboot/config.yml`:

```yaml
simulators:
  tests:
    name: xcboot-test-sim
    device: iPhone 16 Pro
    os: 18-0
    arch: arm64
```

`simulator.sh` can:
- Create simulators (`--create`)
- Delete simulators (`--delete`)
- List simulators (`--list`)

## CI/CD Architecture

### GitHub Actions (Full Support)

```yaml
jobs:
  lint:   # Run SwiftLint
  format: # Check SwiftFormat
  build:  # Build project
  test:   # Run tests with coverage
```

Full integration with GitHub's ecosystem.

### GitLab CI (Basic Support)

```yaml
test:
  script:
    - ./scripts/preflight.sh
```

Calls preflight which runs all checks.

### Bitbucket Pipelines (Basic Support)

```yaml
pipelines:
  default:
    - step:
        script:
          - ./scripts/preflight.sh
```

Similar to GitLab - basic integration.

## Upgrade Path

### Upgrading xcboot

Users can upgrade with:

```bash
curl -fsSL https://...bootstrap.sh | bash -s -- --force
```

The `--force` flag:
- Overwrites all xcboot-managed files
- Preserves `.xcboot.yml` user overrides
- Updates scripts, configs, and CI

### Version Management

- `VERSION` file contains current version
- `CHANGELOG.md` documents changes
- Git tags for releases (`v0.1.0`)

## Security Considerations

### Script Execution

- All scripts use `set -euo pipefail` for safety
- No `eval` or dynamic code execution
- Template variables validated before replacement

### Download from GitHub

- Uses HTTPS (`https://raw.githubusercontent.com`)
- Downloads from specific repo/branch
- No arbitrary code execution from external sources

### Git Hooks

- Pre-commit hook only runs local scripts
- User can disable hooks (`git commit --no-verify`)
- Non-destructive checks only

## Performance Considerations

### Fast Detection

- Uses native git/xcodebuild commands
- Minimal external dependencies
- Caches nothing (stateless)

### Minimal Downloads

- Only downloads needed files
- No large dependencies
- Pure bash (no runtime required)

### Parallel Installation

Could be improved in future:
- Download files in parallel
- Run detections concurrently
- Cache downloaded templates

## Future Extensions

### Planned Features

1. **More Templates**
   - SwiftUI-specific template
   - Clean Architecture template
   - SPM (Swift Package Manager) template

2. **Enhanced CI Support**
   - Better GitLab CI integration
   - Better Bitbucket integration
   - CircleCI support

3. **Additional Hooks**
   - Pre-push hooks
   - Post-merge hooks
   - Custom hook support

4. **Plugin System**
   - User-defined scripts
   - Third-party integrations
   - Custom template variables

### Architecture for Plugins

Potential plugin system:

```
.xcboot/
  plugins/
    my-plugin/
      config.yml
      scripts/
        custom-check.sh
```

Would integrate with existing scripts via hooks.

## Development Architecture

### xcboot Development Scripts

Located in `./scripts/` (not `templates/`):

- **lint.sh** - Lint xcboot's bash scripts with shellcheck
- **format.sh** - Format xcboot's bash scripts with shfmt
- **validate.sh** - Validate YAML templates with yq
- **test.sh** - Run xcboot test suite

### Testing Strategy

Current tests (`./scripts/test.sh`):

1. File structure validation
2. Script permissions check
3. YAML validation
4. VERSION file check
5. CI configs presence

Future tests:
- Integration tests with real Xcode projects
- Template variable replacement tests
- Configuration hierarchy tests
- Multi-provider CI tests

### CI for xcboot

GitHub Actions workflow (`.github/workflows/ci.yml`):

1. Lint all shell scripts
2. Check formatting
3. Validate YAML files
4. Run test suite
5. Test bootstrap dry run

## Design Decisions

### Why Bash?

- Universal on macOS
- No runtime dependencies
- Fast and lightweight
- Easy to audit
- Simple to contribute

### Why Template Variables?

- Simple sed replacement
- No template engine needed
- Easy to understand
- Fast processing

### Why Two-Tier Config?

- Team defaults (committed)
- Personal preferences (gitignored)
- Clear override hierarchy
- Flexible for all use cases

### Why Bootstrap from Within?

- Avoids directory nesting
- Works with existing projects
- Familiar to fastlane users
- Simple mental model

### Why Multi-Provider?

- Not everyone uses GitHub
- Future-proof design
- Demonstrates extensibility
- Real-world need

## Conclusion

xcboot's architecture prioritizes:

1. **Simplicity** - Bash scripts, simple templates
2. **Flexibility** - Two-tier config, multiple providers
3. **Extensibility** - Template system, hooks
4. **Developer Experience** - Fast, predictable, zero-config

This architecture should serve the project well as it grows and evolves.
