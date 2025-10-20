# xcboot Development Guide

This guide covers development workflow, testing, contributing, and release processes for xcboot.

## Getting Started

### Prerequisites

Install development dependencies:

```bash
brew bundle
```

This installs:
- `shellcheck` - Shell script linter
- `shfmt` - Shell script formatter
- `yq` - YAML processor
- `jq` - JSON processor
- `gh` - GitHub CLI

### Editor Setup (Optional)

If using VSCode, the repository includes workspace configuration:

- **Recommended extensions** - Install when prompted for:
  - YAML editing (redhat.vscode-yaml)
  - Shell script linting (timonwong.shellcheck)
  - Shell script formatting (foxundermoon.shell-format)
  - Markdown editing (yzhang.markdown-all-in-one)
  - GitHub Actions (github.vscode-github-actions)

- **Workspace settings** - Pre-configured for:
  - Automatic shellcheck integration
  - shfmt formatting on save
  - YAML schema validation
  - Markdown optimizations

### Repository Structure

```
xcboot/
├── bootstrap.sh           # Main entry point
├── VERSION                # Current version
├── CHANGELOG.md           # Release notes
├── CONTRIBUTING.md        # Contribution guidelines
├── scripts/               # Development scripts
│   ├── lint.sh           # Lint xcboot scripts
│   ├── format.sh         # Format xcboot scripts
│   ├── validate.sh       # Validate YAML templates
│   └── test.sh           # Test xcboot
└── templates/            # Template files
    └── default/          # Default template
```

## Development Workflow

### 1. Make Changes

Edit files as needed:
- `bootstrap.sh` - Main installer logic
- `templates/default/` - Template files
- `scripts/` - Development scripts
- `docs/` - Documentation

### 2. Lint Your Changes

Run shellcheck on all shell scripts:

```bash
./scripts/lint.sh
```

**Common issues:**

```bash
# ❌ Unquoted variable
echo $PROJECT_NAME

# ✅ Quoted variable
echo "$PROJECT_NAME"
```

```bash
# ❌ Missing braces
echo $PROJECT_NAME_SUFFIX

# ✅ With braces
echo "${PROJECT_NAME}_SUFFIX"
```

### 3. Format Your Changes

Format shell scripts with shfmt:

```bash
# Check formatting
./scripts/format.sh

# Fix formatting
./scripts/format.sh --fix
```

**Format rules:**
- 2 space indentation (`-i 2`)
- Simplify code (`-s`)
- Binary ops at start of line (`-bn`)

### 4. Validate YAML

Validate all YAML template files:

```bash
./scripts/validate.sh
```

**Common YAML issues:**

```yaml
# ❌ Unquoted template variable
name: {{PROJECT_NAME}}

# ✅ Quoted template variable
name: "{{PROJECT_NAME}}"
```

### 5. Run Tests

Run the full test suite:

```bash
./scripts/test.sh
```

Tests include:
- File structure validation
- Script permissions
- YAML validation
- VERSION file check
- CI config presence

### 6. Test Bootstrap Manually

Test bootstrap.sh with a real Xcode project:

```bash
# Go to test project
cd /path/to/test/project

# Run bootstrap (use local version, not GitHub)
/path/to/xcboot/bootstrap.sh

# Test with force flag
/path/to/xcboot/bootstrap.sh --force

# Test installed scripts
./scripts/build.sh
./scripts/test.sh
./scripts/preflight.sh
```

### 7. Commit Changes

```bash
git add .
git commit -m "feat: description of changes"
```

**Commit message format:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `refactor:` - Code refactoring
- `test:` - Test changes
- `chore:` - Maintenance

## Development Scripts

### lint.sh

Lints all shell scripts using shellcheck:

```bash
./scripts/lint.sh
```

**What it checks:**
- Syntax errors
- Undefined variables
- Quote issues
- Best practices
- Common mistakes

**Suppressing warnings:**

```bash
# shellcheck disable=SC2086
echo $UNQUOTED_VAR  # Intentionally unquoted
```

### format.sh

Formats shell scripts using shfmt:

```bash
# Check formatting (exit 1 if bad)
./scripts/format.sh

# Fix formatting
./scripts/format.sh --fix
```

**Format style:**
```bash
# Before
if [ -f "$file" ];then
    echo "found"
fi

# After
if [[ -f "$file" ]]; then
  echo "found"
fi
```

### validate.sh

Validates YAML files using yq:

```bash
./scripts/validate.sh
```

**Finds:**
- YAML syntax errors
- Invalid structure
- Parse errors
- Template variable issues

### test.sh

Runs test suite:

```bash
./scripts/test.sh
```

**Tests:**
1. File structure - All required files present
2. Script permissions - Scripts are executable
3. YAML validation - All YAML valid
4. VERSION check - Valid semver
5. CI configs - All CI files present

**Adding new tests:**

Edit `scripts/test.sh`:

```bash
test_new_feature() {
  log_info "Test 6: Testing new feature..."

  # Test logic here
  if [[ condition ]]; then
    log_success "Test passed ✓"
    return 0
  else
    log_error "Test failed"
    return 1
  fi
}

# Add to main()
main() {
  # ... existing tests ...
  test_new_feature || failed=$((failed + 1))
  # ...
}
```

## Testing

### Unit Testing

Currently manual testing. Future: automated shell script tests.

### Integration Testing

Test bootstrap.sh with real projects:

```bash
# Create test project
mkdir -p /tmp/test-project
cd /tmp/test-project

# Create minimal .xcodeproj
mkdir TestApp.xcodeproj
cat > TestApp.xcodeproj/project.pbxproj <<EOF
IPHONEOS_DEPLOYMENT_TARGET = 18.0;
PRODUCT_BUNDLE_IDENTIFIER = com.test.TestApp;
EOF

# Initialize git
git init
git remote add origin https://github.com/test/test.git

# Run bootstrap
/path/to/xcboot/bootstrap.sh

# Test scripts
./scripts/build.sh --help
./scripts/test.sh --help
```

### CI Testing

GitHub Actions runs on every push:

```yaml
jobs:
  lint:      # shellcheck
  format:    # shfmt
  validate:  # yq
  test:      # test suite
  bootstrap: # dry run test
```

### Manual Testing Checklist

Before releasing:

- [ ] Run `./scripts/lint.sh` - passes
- [ ] Run `./scripts/format.sh` - passes
- [ ] Run `./scripts/validate.sh` - passes
- [ ] Run `./scripts/test.sh` - passes
- [ ] Test bootstrap with new project
- [ ] Test bootstrap with existing project
- [ ] Test `--force` flag
- [ ] Test `--no-status` flag
- [ ] Test `--structure` flag
- [ ] Test all installed scripts work
- [ ] Test GitHub CI config
- [ ] Test GitLab CI config (if possible)
- [ ] Test Bitbucket config (if possible)

## Working with Templates

### Adding Files to Templates

1. Create file in `templates/default/`:

```bash
vim templates/default/scripts/new-script.sh
```

2. Add template variables:

```bash
#!/usr/bin/env bash
PROJECT="{{PROJECT_NAME}}"
```

3. Add installation to `bootstrap.sh`:

```bash
install_scripts() {
  # ... existing scripts ...
  install_file "$template" "scripts/new-script.sh" "scripts/new-script.sh" "${vars[@]}"
  chmod +x scripts/new-script.sh
}
```

4. Add to test suite:

```bash
# In scripts/test.sh
required_files=(
  # ... existing files ...
  "templates/default/scripts/new-script.sh"
)
```

### Adding Template Variables

1. Add to `replace_variables()` in bootstrap.sh:

```bash
replace_variables() {
  local content="$1"
  # ... existing variables ...
  content="${content//\{\{MY_NEW_VAR\}\}/$my_new_value}"
  echo "$content"
}
```

2. Update `install_file()` signature if needed

3. Document in `docs/TEMPLATES.md`

4. Use in template files:

```yaml
# templates/default/.xcboot/config.yml
my_config:
  value: "{{MY_NEW_VAR}}"
```

### Creating New Templates

See [TEMPLATES.md](TEMPLATES.md) for detailed guide.

Quick steps:

```bash
# Create template
mkdir -p templates/mytemplate
cp -r templates/default/* templates/mytemplate/

# Customize
vim templates/mytemplate/scripts/build.sh

# Test
cd /tmp/test-project
/path/to/xcboot/bootstrap.sh --template mytemplate
```

## Working with Bootstrap Script

### bootstrap.sh Structure

```bash
# Configuration
FORCE_INSTALL=false
TEMPLATE="default"

# Argument parsing
parse_arguments() { ... }

# Detection functions
detect_project_name() { ... }
detect_git_provider() { ... }
detect_deployment_target() { ... }

# Installation functions
install_file() { ... }
install_scripts() { ... }
install_configs() { ... }

# Main function
main() {
  # 1. Detect
  # 2. Prompt
  # 3. Install
  # 4. Success message
}
```

### Adding Detection Logic

Example: Detect Xcode version

```bash
detect_xcode_version() {
  if command_exists xcodebuild; then
    xcodebuild -version | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "15.0"
  else
    echo "15.0"
  fi
}
```

Add to main():

```bash
main() {
  # ... existing detection ...
  local xcode_version
  xcode_version=$(detect_xcode_version)
  log_info "Xcode version: $xcode_version"
}
```

### Adding Installation Functions

Example: Install additional configs

```bash
install_danger_config() {
  local template="$1"
  shift
  local vars=("$@")

  log_step "Installing Danger configuration..."
  install_file "$template" "configs/Dangerfile" "Dangerfile" "${vars[@]}"
  echo
}
```

Call from main():

```bash
main() {
  # ... existing installation ...
  install_danger_config "$TEMPLATE" "${vars[@]}"
}
```

## Debugging

### Verbose Output

Add to beginning of script:

```bash
set -x  # Print commands
```

Or run with bash -x:

```bash
bash -x ./bootstrap.sh
```

### Check Variable Values

Add debug logging:

```bash
log_info "DEBUG: project_name=$project_name"
log_info "DEBUG: bundle_id_root=$bundle_id_root"
```

### Test Specific Functions

Source the script and test functions:

```bash
# In test shell
source ./bootstrap.sh

# Test specific function
detect_project_name
detect_git_provider
```

### Common Issues

**Issue: Variable not replaced**

```bash
# Check replace_variables() includes your variable
content="${content//\{\{MY_VAR\}\}/$my_value}"
```

**Issue: File not installed**

```bash
# Check install_file() is called
install_file "$template" "source" "dest" "${vars[@]}"
```

**Issue: Script not executable**

```bash
# Add chmod +x after install
chmod +x scripts/my-script.sh
```

## Release Process

### 1. Update Version

Edit `VERSION` file:

```bash
echo "0.2.0" > VERSION
```

### 2. Update CHANGELOG

Edit `CHANGELOG.md`:

```markdown
## [0.2.0] - 2024-01-15

### Added
- New feature X
- New feature Y

### Changed
- Updated Z

### Fixed
- Bug in A
```

### 3. Update Bootstrap Version

Edit `bootstrap.sh`:

```bash
readonly XCBOOT_VERSION="0.2.0"
```

### 4. Run All Tests

```bash
./scripts/lint.sh
./scripts/format.sh
./scripts/validate.sh
./scripts/test.sh
```

### 5. Manual Testing

Test with real project as described above.

### 6. Commit Release

```bash
git add VERSION CHANGELOG.md bootstrap.sh
git commit -m "chore: bump version to 0.2.0"
```

### 7. Tag Release

```bash
git tag -a v0.2.0 -m "Release v0.2.0"
git push origin main
git push origin v0.2.0
```

### 8. Create GitHub Release

```bash
gh release create v0.2.0 \
  --title "v0.2.0" \
  --notes-file CHANGELOG.md
```

### 9. Announce

- Update README badges if needed
- Announce in discussions
- Update documentation

## Contributing

### Contribution Workflow

1. **Fork** the repository
2. **Clone** your fork
3. **Create branch** (`git checkout -b feature/my-feature`)
4. **Make changes**
5. **Test** (lint, format, validate, test)
6. **Commit** with descriptive message
7. **Push** to your fork
8. **Create PR** with description

### PR Guidelines

**Good PR:**
- Clear title and description
- Tests pass (CI green)
- Follows code style
- Includes documentation updates
- Small, focused changes

**PR Checklist:**
- [ ] Tests pass locally
- [ ] shellcheck passes
- [ ] shfmt formatting applied
- [ ] YAML validation passes
- [ ] Documentation updated
- [ ] CHANGELOG.md updated (if user-facing)
- [ ] Tested manually with real project

### Code Style

**Shell scripts:**
- Use `#!/usr/bin/env bash`
- Use `set -euo pipefail`
- Quote all variables: `"$var"`
- Use `[[ ]]` instead of `[ ]`
- Use functions for reusable code
- Add comments for complex logic
- 2 space indentation

**YAML:**
- 2 space indentation
- Quote template variables
- Use descriptive keys
- Add comments for clarity

**Documentation:**
- Use Markdown
- Include examples
- Update when changing behavior
- Keep README.md up to date

## Troubleshooting Development

### shellcheck Errors

**SC2086: Quote variable**
```bash
# ❌
echo $VAR

# ✅
echo "$VAR"
```

**SC2046: Quote command substitution**
```bash
# ❌
files=$(find . -name "*.sh")

# ✅
files="$(find . -name "*.sh")"
```

**SC2155: Separate declaration and assignment**
```bash
# ❌
local var=$(command)

# ✅
local var
var=$(command)
```

### shfmt Issues

**Indentation wrong**
```bash
# Run format --fix
./scripts/format.sh --fix
```

**Binary ops wrong**
```bash
# Before
echo "foo" \
  | grep bar

# After (with -bn)
echo "foo" |
  grep bar
```

### YAML Validation Errors

**Template variable unquoted**
```yaml
# ❌
name: {{PROJECT_NAME}}

# ✅
name: "{{PROJECT_NAME}}"
```

**Invalid YAML structure**
```bash
# Use yq to validate
yq eval '.' file.yml
```

## Tips and Tricks

### Quick Test Loop

```bash
# Watch for changes and auto-test
while true; do
  clear
  ./scripts/lint.sh && ./scripts/format.sh && ./scripts/validate.sh && ./scripts/test.sh
  sleep 2
done
```

### Test Specific Script

```bash
# Test just one template script
cd /tmp/test-project
/path/to/xcboot/templates/default/scripts/build.sh
```

### Validate One File

```bash
# Validate single YAML file
yq eval '.' templates/default/.xcboot/config.yml
```

### Check Script Syntax

```bash
# Check bash syntax
bash -n script.sh

# Check with shellcheck
shellcheck script.sh
```

## Resources

### Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture details
- [TEMPLATES.md](TEMPLATES.md) - Template system guide
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Contribution guidelines
- [CLAUDE.md](../CLAUDE.md) - Claude Code assistance

### External Resources

- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
- [shfmt](https://github.com/mvdan/sh)
- [yq documentation](https://mikefarah.gitbook.io/yq/)
- [Bash Manual](https://www.gnu.org/software/bash/manual/)

### Tools

- [shellcheck](https://www.shellcheck.net/) - Shell linter
- [shfmt](https://github.com/mvdan/sh) - Shell formatter
- [yq](https://github.com/mikefarah/yq) - YAML processor
- [jq](https://stedolan.github.io/jq/) - JSON processor

## Getting Help

### Issues

Report bugs or request features:
https://github.com/nickhart/xcboot/issues

### Discussions

Ask questions or share ideas:
https://github.com/nickhart/xcboot/discussions

### Pull Requests

Contribute code:
https://github.com/nickhart/xcboot/pulls

## Conclusion

xcboot development is straightforward:

1. Make changes
2. Lint, format, validate, test
3. Test manually
4. Submit PR

Follow the guidelines, write good code, and help make xcboot better for everyone!
