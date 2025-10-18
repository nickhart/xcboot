# Contributing to xcboot

Thank you for your interest in contributing to xcboot! This document provides guidelines and instructions for contributing.

## Getting Started

### Prerequisites

Install development dependencies:

```bash
brew bundle install
```

This installs:
- `shellcheck` - Shell script linting
- `shfmt` - Shell script formatting
- `yq` - YAML processing
- `jq` - JSON processing
- `gh` - GitHub CLI
- iOS development tools (xcodegen, swiftlint, swiftformat, xcbeautify)

### Development Workflow

1. **Fork and clone** the repository
2. **Create a branch** for your feature or bug fix
3. **Make your changes** following our coding standards
4. **Test your changes** thoroughly
5. **Submit a pull request**

## Project Structure

```
xcboot/
├── bootstrap.sh              # Main installer script
├── scripts/                  # Development scripts for xcboot itself
│   ├── lint.sh              # Lint all shell scripts
│   ├── format.sh            # Format all shell scripts
│   ├── test.sh              # Test bootstrap process
│   └── validate.sh          # Validate template files
└── templates/default/       # Files distributed to users
    ├── .xcboot/            # User project config
    ├── scripts/            # User project scripts
    ├── configs/            # SwiftLint, SwiftFormat configs
    └── ci/                 # CI configs for different providers
```

## Coding Standards

### Shell Scripts

All shell scripts must:
- Use `#!/usr/bin/env bash` shebang
- Include `set -euo pipefail` for safety
- Pass `shellcheck` linting
- Be formatted with `shfmt -i 2`
- Include helpful comments
- Have proper error handling

Run quality checks:

```bash
./scripts/lint.sh      # Lint all scripts
./scripts/format.sh    # Format all scripts
```

### YAML Files

All YAML files must:
- Pass `yq` validation
- Use 2-space indentation
- Include comments explaining configuration options

### Template Variables

Use `{{VARIABLE_NAME}}` syntax for template placeholders:
- `{{PROJECT_NAME}}`
- `{{BUNDLE_ID_ROOT}}`
- `{{DEPLOYMENT_TARGET}}`
- `{{SWIFT_VERSION}}`

## Testing

Before submitting a PR:

1. **Lint scripts**: `./scripts/lint.sh`
2. **Format scripts**: `./scripts/format.sh`
3. **Validate templates**: `./scripts/validate.sh`
4. **Test bootstrap**: `./scripts/test.sh`
5. **Manual testing**: Run `bootstrap.sh` on a test project

## Pull Request Process

1. Update CHANGELOG.md with your changes
2. Ensure all scripts pass linting and formatting
3. Test bootstrap.sh on both existing and new projects
4. Update documentation if needed
5. Submit PR with clear description of changes

### PR Title Format

Use conventional commit style:
- `feat: Add support for X`
- `fix: Resolve issue with Y`
- `docs: Update documentation for Z`
- `refactor: Improve W implementation`
- `test: Add tests for V`

## CI Provider Support

### Fully Supported (Production Ready)
- ✅ **GitHub Actions** - Maintained by project owner

### Basic Support (Community Contributions Welcome)
- 🚧 **GitLab CI** - Basic config provided
- 🚧 **Bitbucket Pipelines** - Basic config provided

If you use GitLab or Bitbucket, we welcome contributions to improve those integrations!

## Adding New Templates

To add a new template (e.g., SwiftUI, Clean Architecture):

1. Create `templates/<template-name>/` directory
2. Include all necessary files (.xcboot/config.yml, scripts/, etc.)
3. Update `bootstrap.sh` to support `--template <template-name>` flag
4. Document the template in README.md

## Questions or Issues?

- **Bug reports**: Open an issue with detailed reproduction steps
- **Feature requests**: Open an issue describing the use case
- **Questions**: Start a discussion or open an issue

## Code of Conduct

Be respectful, constructive, and collaborative. We're all here to build better tools for iOS development.

## License

By contributing to xcboot, you agree that your contributions will be licensed under the MIT License.
