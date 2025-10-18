# xcboot

**Bootstrap Tool for iOS Projects**

Instantly add CI/CD, quality tools, helper scripts, and automation to any Xcode project with a single command.

[![CI](https://github.com/nickhart/xcboot/actions/workflows/ci.yml/badge.svg)](https://github.com/nickhart/xcboot/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-green.svg)](VERSION)

## Features

- 🚀 **One-command setup** - Bootstrap existing Xcode projects in seconds
- 🔄 **Multi-CI support** - Auto-detects and configures GitHub Actions, GitLab CI, or Bitbucket Pipelines
- 🛠 **Automation scripts** - Build, test, lint, format, preflight, and simulator management
- 📱 **Smart simulator detection** - Auto-configures iOS simulators based on deployment target
- 🎯 **Quality tools** - SwiftLint and SwiftFormat with sensible defaults
- 🪝 **Git hooks** - Pre-commit checks to maintain code quality
- 📊 **Project templates** - Includes XcodeGen project.yml and STATUS.md
- 🔧 **Customizable** - Override defaults with `.xcboot.yml` configuration

## Quick Start

### Bootstrap Existing Project

```bash
cd YourExistingProject
curl -fsSL https://raw.githubusercontent.com/nickhart/xcboot/main/bootstrap.sh | bash
```

### With Options

```bash
# Force upgrade to latest version
curl -fsSL https://raw.githubusercontent.com/nickhart/xcboot/main/bootstrap.sh | bash -s -- --force

# Create with MVVM directory structure
curl -fsSL https://raw.githubusercontent.com/nickhart/xcboot/main/bootstrap.sh | bash -s -- --structure

# Skip STATUS.md generation
curl -fsSL https://raw.githubusercontent.com/nickhart/xcboot/main/bootstrap.sh | bash -s -- --no-status
```

## What Gets Installed

### Automation Scripts (`./scripts/`)

- **build.sh** - Build your project with xcodebuild or xcodegen
- **test.sh** - Run unit and UI tests with coverage
- **lint.sh** - Run SwiftLint on your codebase
- **format.sh** - Format code with SwiftFormat
- **preflight.sh** - Run all checks before pushing (lint + format + build + test)
- **simulator.sh** - Manage iOS simulators (create, delete, list)
- **pre-commit.sh** - Git pre-commit hook script

### Configuration Files

- **.swiftlint.yml** - SwiftLint configuration with sensible rules
- **.swiftformat** - SwiftFormat configuration
- **.xcboot/config.yml** - xcboot configuration (simulator settings, project metadata)

### CI/CD Configuration

Auto-detects git provider and installs appropriate CI config:

- **GitHub Actions** (`.github/workflows/ci.yml`) - Full support with build, test, lint, format
- **GitLab CI** (`.gitlab-ci.yml`) - Basic support calling preflight script
- **Bitbucket Pipelines** (`bitbucket-pipelines.yml`) - Basic support calling preflight script

### Optional Files

- **STATUS.md** - Project status template (enabled by default, disable with `--no-status`)
- **project.yml** - XcodeGen project template (for new projects)

### Git Hooks

- **pre-commit** - Runs preflight checks before allowing commits

## Usage

After bootstrapping, use the installed scripts:

```bash
# Set up simulators
./scripts/simulator.sh

# Run preflight checks (recommended before pushing)
./scripts/preflight.sh

# Build your project
./scripts/build.sh

# Run tests
./scripts/test.sh

# Lint code
./scripts/lint.sh

# Format code
./scripts/format.sh --fix
```

## Configuration

### Default Configuration (`.xcboot/config.yml`)

Installed automatically with detected values. Example:

```yaml
version: "1.0"
project:
  name: MyApp
  bundle_id_root: com.mycompany
  deployment_target: 18.0
  swift_version: 6.2
ci:
  provider: github
  enabled: true
simulators:
  tests:
    name: xcboot-test-sim
    device: iPhone 16 Pro
    os: 18-0
    arch: arm64
```

### User Overrides (`.xcboot.yml`)

Create `.xcboot.yml` in your project root to override defaults:

```yaml
# Override simulator for tests
simulators:
  tests:
    device: iPhone 15 Pro
    os: 17-5

# Disable CI checks
ci:
  enabled: false
```

**Note**: `.xcboot.yml` should be in `.gitignore` for local developer preferences.

## Architecture

### Directory Structure

```
xcboot/
├── bootstrap.sh              # Main installer (downloads from GitHub)
├── VERSION                   # Current version (0.1.0)
├── Brewfile                  # Development dependencies
├── CHANGELOG.md              # Release history
├── CONTRIBUTING.md           # Contribution guidelines
├── CLAUDE.md                 # Claude Code assistance guide
├── scripts/                  # xcboot development scripts
│   ├── lint.sh              # Lint xcboot shell scripts
│   ├── format.sh            # Format xcboot shell scripts
│   ├── validate.sh          # Validate YAML templates
│   └── test.sh              # Test xcboot functionality
├── templates/
│   └── default/             # Default template
│       ├── scripts/         # User project scripts (distributed)
│       ├── configs/         # Configuration files (distributed)
│       ├── ci/              # CI configurations (distributed)
│       │   ├── github/
│       │   ├── gitlab/
│       │   └── bitbucket/
│       ├── .xcboot/         # xcboot config template
│       ├── project.yml      # XcodeGen project template
│       └── STATUS.md        # Status documentation template
└── .github/
    └── workflows/
        └── ci.yml           # CI for xcboot itself
```

### How It Works

1. **Detection Phase**
   - Detects Xcode project name from `.xcodeproj` or `project.yml`
   - Detects git provider from `git remote get-url origin`
   - Detects deployment target from project.pbxproj
   - Detects Swift version from `swift --version`
   - Detects optimal simulator based on deployment target

2. **Installation Phase**
   - Downloads template files from GitHub
   - Replaces template variables (`{{PROJECT_NAME}}`, `{{DEPLOYMENT_TARGET}}`, etc.)
   - Installs scripts, configs, and CI based on detected provider
   - Sets executable permissions on scripts
   - Installs git pre-commit hook
   - Creates `.xcboot/config.yml` with detected values

3. **Customization Phase**
   - User can create `.xcboot.yml` to override defaults
   - Scripts read user overrides first, fall back to system config

## Development

### Prerequisites

```bash
brew bundle  # Installs shellcheck, shfmt, yq, jq, gh
```

### Development Workflow

```bash
# Lint shell scripts
./scripts/lint.sh

# Format shell scripts
./scripts/format.sh --fix

# Validate YAML templates
./scripts/validate.sh

# Run test suite
./scripts/test.sh
```

### Testing Bootstrap Script

```bash
# Test in existing Xcode project
cd /path/to/test/project
/path/to/xcboot/bootstrap.sh

# Test with force flag
/path/to/xcboot/bootstrap.sh --force
```

## Multi-Provider CI Support

xcboot supports three CI providers with auto-detection:

| Provider | Support Level | Features |
|----------|--------------|----------|
| **GitHub Actions** | ✅ Full | Build, test, lint, format, coverage |
| **GitLab CI** | ⚠️ Basic | Calls `./scripts/preflight.sh` |
| **Bitbucket Pipelines** | ⚠️ Basic | Calls `./scripts/preflight.sh` |

### Extending CI Support

To improve GitLab or Bitbucket support, edit:
- `templates/default/ci/gitlab/.gitlab-ci.yml`
- `templates/default/ci/bitbucket/bitbucket-pipelines.yml`

## Templates

xcboot uses a template system for extensibility. The `default` template is currently available.

Future templates might include:
- `swiftui` - SwiftUI-specific project setup
- `clean` - Clean Architecture project structure
- `spm` - Swift Package Manager project

### Creating Custom Templates

1. Create `templates/yourtemplate/` directory
2. Add scripts, configs, and CI configurations
3. Use template variables: `{{PROJECT_NAME}}`, `{{DEPLOYMENT_TARGET}}`, etc.
4. Test with `./bootstrap.sh --template yourtemplate`

## Requirements

- macOS with Xcode installed
- Git repository (for git provider detection)
- Existing Xcode project (`.xcodeproj`) or `project.yml` for xcodegen

### Optional Dependencies

- **xcodegen** - For project.yml support
- **yq** - For YAML configuration parsing
- **swiftlint** - For linting (installed by CI or manually)
- **swiftformat** - For formatting (installed by CI or manually)

## Upgrading

To upgrade an existing xcboot installation:

```bash
curl -fsSL https://raw.githubusercontent.com/nickhart/xcboot/main/bootstrap.sh | bash -s -- --force
```

This will overwrite all xcboot-managed files with the latest versions.

**Note**: Your `.xcboot.yml` user overrides will not be modified.

## Troubleshooting

### "No Xcode project found"

Make sure you're in a directory with a `.xcodeproj` file or a `project.yml` file for xcodegen.

### "File exists, skipping"

Use `--force` flag to overwrite existing files during upgrades.

### Scripts not executable

Run `chmod +x scripts/*.sh` to make scripts executable.

### Simulators not working

Run `./scripts/simulator.sh` to create and configure simulators.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Credits

Created by [Nick Hart](https://github.com/nickhart)

Inspired by [fastlane](https://fastlane.tools/), [oh-my-zsh](https://ohmyz.sh/), and other bootstrap tools.

---

**xcboot** - Bootstrap your Xcode projects with confidence! 🚀
