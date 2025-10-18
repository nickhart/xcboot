# xcboot Templates Guide

This guide explains how xcboot's template system works and how to create custom templates.

## Overview

xcboot uses a template-based architecture to support different project types and configurations. The `default` template provides a solid foundation for most iOS projects, but you can create custom templates for specific needs.

## Template Structure

A template is a directory under `templates/` containing:

```
templates/mytemplate/
├── scripts/              # Automation scripts
├── configs/              # Configuration files
├── ci/                   # CI configurations
├── .xcboot/              # xcboot config
├── project.yml           # XcodeGen template (optional)
└── STATUS.md             # Status template (optional)
```

## Default Template

The `default` template includes:

### Scripts (`scripts/`)

| Script | Purpose |
|--------|---------|
| `_helpers.sh` | Shared helper functions |
| `build.sh` | Build the project |
| `test.sh` | Run tests with coverage |
| `lint.sh` | Run SwiftLint |
| `format.sh` | Format code with SwiftFormat |
| `preflight.sh` | Run all checks before push |
| `simulator.sh` | Manage iOS simulators |
| `pre-commit.sh` | Git pre-commit hook script |

### Configs (`configs/`)

| File | Purpose |
|------|---------|
| `swiftlint.yml` | SwiftLint configuration |
| `swiftformat` | SwiftFormat configuration |

### CI Configs (`ci/`)

Three providers supported:

```
ci/
├── github/
│   ├── workflows/ci.yml
│   └── pull_request_template.md
├── gitlab/
│   ├── .gitlab-ci.yml
│   └── merge_request_templates/default.md
└── bitbucket/
    ├── bitbucket-pipelines.yml
    └── pull_request_template.md
```

### xcboot Config (`.xcboot/`)

System configuration template:

```yaml
version: "1.0"
project:
  name: {{PROJECT_NAME}}
  bundle_id_root: {{BUNDLE_ID_ROOT}}
  deployment_target: {{DEPLOYMENT_TARGET}}
  swift_version: {{SWIFT_VERSION}}
ci:
  provider: {{CI_PROVIDER}}
  enabled: true
simulators:
  tests:
    name: {{SIMULATOR_TESTS_NAME}}
    device: {{SIMULATOR_TESTS_DEVICE}}
    os: {{SIMULATOR_TESTS_OS}}
    arch: {{SIMULATOR_TESTS_ARCH}}
  ui-tests:
    name: {{SIMULATOR_UI_TESTS_NAME}}
    device: {{SIMULATOR_UI_TESTS_DEVICE}}
    os: {{SIMULATOR_UI_TESTS_OS}}
    arch: {{SIMULATOR_UI_TESTS_ARCH}}
```

## Template Variables

### Standard Variables

All templates have access to these variables:

| Variable | Description | Example | Detection |
|----------|-------------|---------|-----------|
| `{{PROJECT_NAME}}` | Xcode project name | `MyApp` | .xcodeproj name |
| `{{BUNDLE_ID_ROOT}}` | Bundle ID prefix | `com.mycompany` | User prompt or detection |
| `{{DEPLOYMENT_TARGET}}` | iOS deployment target | `18.0` | project.pbxproj |
| `{{SWIFT_VERSION}}` | Swift version | `6.2` | `swift --version` |
| `{{CI_PROVIDER}}` | Git provider | `github` | `git remote` |

### Simulator Variables

Auto-configured based on deployment target:

| Variable | Description | Example |
|----------|-------------|---------|
| `{{SIMULATOR_TESTS_NAME}}` | Test simulator name | `xcboot-test-sim` |
| `{{SIMULATOR_TESTS_DEVICE}}` | Test device model | `iPhone 16 Pro` |
| `{{SIMULATOR_TESTS_OS}}` | Test iOS version | `18-0` |
| `{{SIMULATOR_TESTS_ARCH}}` | Test architecture | `arm64` |
| `{{SIMULATOR_UI_TESTS_NAME}}` | UI test simulator name | `xcboot-ui-test-sim` |
| `{{SIMULATOR_UI_TESTS_DEVICE}}` | UI test device model | `iPhone 16 Pro` |
| `{{SIMULATOR_UI_TESTS_OS}}` | UI test iOS version | `18-0` |
| `{{SIMULATOR_UI_TESTS_ARCH}}` | UI test architecture | `arm64` |

### Using Variables in Templates

Variables use `{{VARIABLE}}` syntax and work in any text file:

**Shell script example:**
```bash
#!/usr/bin/env bash
PROJECT_NAME="{{PROJECT_NAME}}"
BUNDLE_ID="{{BUNDLE_ID_ROOT}}.{{PROJECT_NAME}}"
```

**YAML example:**
```yaml
name: "{{PROJECT_NAME}}"
options:
  bundleIdPrefix: "{{BUNDLE_ID_ROOT}}"
  deploymentTarget:
    iOS: "{{DEPLOYMENT_TARGET}}"
```

**Markdown example:**
```markdown
# {{PROJECT_NAME}} Status

- **Deployment Target:** iOS {{DEPLOYMENT_TARGET}}
- **Swift Version:** {{SWIFT_VERSION}}
```

### YAML Variable Quoting

**Important:** Template variables in YAML must be quoted:

```yaml
# ✅ Correct
name: "{{PROJECT_NAME}}"
included:
  - "{{PROJECT_NAME}}"
  - "{{PROJECT_NAME}}Tests"

targets:
  "{{PROJECT_NAME}}":
    type: application

# ❌ Wrong (YAML parse error)
name: {{PROJECT_NAME}}
included:
  - {{PROJECT_NAME}}

targets:
  {{PROJECT_NAME}}:
    type: application
```

## Creating Custom Templates

### Step 1: Create Template Directory

```bash
mkdir -p templates/mytemplate
```

### Step 2: Copy Default Template

Start with the default template as a base:

```bash
cp -r templates/default/* templates/mytemplate/
```

### Step 3: Customize for Your Needs

Example: Creating a SwiftUI template

```bash
cd templates/mytemplate

# Customize build script for SwiftUI projects
vim scripts/build.sh

# Add SwiftUI-specific linting rules
vim configs/swiftlint.yml

# Update CI to test SwiftUI previews
vim ci/github/workflows/ci.yml
```

### Step 4: Test Your Template

```bash
cd /path/to/test/project
/path/to/xcboot/bootstrap.sh --template mytemplate
```

### Step 5: Validate

```bash
cd /path/to/xcboot
./scripts/validate.sh  # Validate YAML files
./scripts/test.sh      # Run tests
```

## Template Examples

### Example 1: SwiftUI Template

Customizations for SwiftUI projects:

**templates/swiftui/scripts/build.sh:**
```bash
# Additional SwiftUI-specific build settings
ENABLE_PREVIEWS=YES xcodebuild build ...
```

**templates/swiftui/configs/swiftlint.yml:**
```yaml
# SwiftUI-specific rules
custom_rules:
  swiftui_state:
    name: "SwiftUI State"
    regex: "@State\\s+var\\s+[a-z]"
    message: "@State should be private"
```

### Example 2: Clean Architecture Template

For Clean Architecture projects with specific structure:

**templates/clean/scripts/preflight.sh:**
```bash
# Additional architecture validation
echo "Validating Clean Architecture..."
./scripts/validate-architecture.sh
```

**templates/clean/configs/swiftlint.yml:**
```yaml
# Enforce layer separation
included:
  - Domain
  - Data
  - Presentation

custom_rules:
  layer_import:
    name: "Layer Import"
    regex: "import\\s+(Domain|Data|Presentation)"
    message: "Check layer dependencies"
```

### Example 3: SPM (Swift Package Manager) Template

For Swift Package projects:

**templates/spm/scripts/build.sh:**
```bash
# Use swift build instead of xcodebuild
swift build
```

**templates/spm/scripts/test.sh:**
```bash
# Use swift test
swift test --enable-code-coverage
```

## Template File Reference

### Required Files

Every template must have:

- `scripts/_helpers.sh` - Core helper functions
- `scripts/build.sh` - Build script
- `scripts/test.sh` - Test script
- `.xcboot/config.yml` - Configuration template

### Optional Files

Templates can optionally include:

- `scripts/lint.sh` - Linting script
- `scripts/format.sh` - Formatting script
- `scripts/preflight.sh` - Pre-flight checks
- `scripts/simulator.sh` - Simulator management
- `scripts/pre-commit.sh` - Git hook script
- `configs/swiftlint.yml` - SwiftLint config
- `configs/swiftformat` - SwiftFormat config
- `ci/github/` - GitHub Actions config
- `ci/gitlab/` - GitLab CI config
- `ci/bitbucket/` - Bitbucket Pipelines config
- `project.yml` - XcodeGen project template
- `STATUS.md` - Status documentation template

### Custom Files

You can add custom files to templates:

```
templates/mytemplate/
├── scripts/
│   └── custom-deploy.sh    # Custom deployment script
├── configs/
│   └── danger.yml          # Danger configuration
└── docs/
    └── SETUP.md            # Custom setup docs
```

Update `bootstrap.sh` to install custom files:

```bash
# In install_scripts function
install_file "$template" "scripts/custom-deploy.sh" "scripts/custom-deploy.sh" "${vars[@]}"
chmod +x scripts/custom-deploy.sh
```

## Advanced Template Techniques

### Conditional File Installation

Install files based on project type:

```bash
# In bootstrap.sh
if [[ -f "project.yml" ]]; then
  # Using xcodegen, install project.yml template
  install_file "$template" "project.yml" "project.yml" "${vars[@]}"
fi
```

### Template-Specific Variables

Add custom variables for your template:

```bash
# In bootstrap.sh replace_variables function
content="${content//\{\{MY_CUSTOM_VAR\}\}/$my_custom_value}"
```

### Multi-File Templates

Create files that reference each other:

**templates/mytemplate/scripts/build.sh:**
```bash
source "$(dirname "$0")/_helpers.sh"
source "$(dirname "$0")/_build_helpers.sh"  # Template-specific helpers

build_{{PROJECT_NAME}}
```

**templates/mytemplate/scripts/_build_helpers.sh:**
```bash
build_{{PROJECT_NAME}}() {
  log_info "Building {{PROJECT_NAME}} with custom settings..."
  # Custom build logic
}
```

### Template Variants

Create variants of templates:

```
templates/
├── default/
├── swiftui/
├── swiftui-spm/        # SwiftUI + SPM variant
└── swiftui-clean/      # SwiftUI + Clean Architecture variant
```

## Template Development Workflow

### 1. Plan Your Template

Identify what's different:
- Scripts needed
- Configs needed
- CI requirements
- Project structure

### 2. Create and Test Locally

```bash
# Create template
mkdir -p templates/mytemplate
cp -r templates/default/* templates/mytemplate/

# Make changes
vim templates/mytemplate/scripts/build.sh

# Test locally
cd /path/to/test/project
/path/to/xcboot/bootstrap.sh --template mytemplate --force
```

### 3. Validate

```bash
# Validate YAML
./scripts/validate.sh

# Run tests
./scripts/test.sh

# Test scripts work
cd /path/to/test/project
./scripts/build.sh
./scripts/test.sh
```

### 4. Document

Add README for your template:

```bash
# templates/mytemplate/README.md
# MyTemplate

This template is designed for [use case].

## Features
- Custom build process
- Specific linting rules
- ...

## Usage
./bootstrap.sh --template mytemplate
```

### 5. Contribute Back

If your template is useful:
1. Add to xcboot repository
2. Update main README.md
3. Add to template list
4. Submit PR

## Template Maintenance

### Updating Templates

When xcboot core changes:
1. Update all templates
2. Test each template
3. Validate YAML
4. Update VERSION
5. Document in CHANGELOG

### Deprecating Templates

If a template is no longer needed:
1. Mark as deprecated in README
2. Keep for one major version
3. Remove in next major version
4. Document in CHANGELOG

## Best Practices

### 1. Use Standard Variables

Always use standard template variables:
- `{{PROJECT_NAME}}`
- `{{BUNDLE_ID_ROOT}}`
- `{{DEPLOYMENT_TARGET}}`
- `{{SWIFT_VERSION}}`
- `{{CI_PROVIDER}}`

### 2. Quote YAML Variables

Always quote template variables in YAML:
```yaml
name: "{{PROJECT_NAME}}"
```

### 3. Test Thoroughly

Test your template with:
- Different project sizes
- Different iOS versions
- Different Swift versions
- Different CI providers

### 4. Document Everything

Include:
- README for template
- Comments in scripts
- Usage examples
- Known limitations

### 5. Keep It Simple

Templates should:
- Build on defaults when possible
- Not duplicate code
- Use `_helpers.sh` functions
- Follow xcboot conventions

### 6. Version Compatibility

Ensure templates work with:
- Current Xcode version
- Current Swift version
- Current iOS version
- Latest xcodegen (if used)

## Troubleshooting Templates

### YAML Parse Errors

```
Error: YAML syntax error
```

**Fix:** Quote all template variables in YAML files.

### Variables Not Replaced

```
File contains: {{PROJECT_NAME}}
```

**Fix:** Ensure variable is in `replace_variables()` function in bootstrap.sh.

### Scripts Not Executable

```
Permission denied
```

**Fix:** Add `chmod +x` in installation script:
```bash
chmod +x scripts/mytemplate-script.sh
```

### File Not Installed

```
File missing after bootstrap
```

**Fix:** Add installation call in bootstrap.sh:
```bash
install_file "$template" "path/in/template" "dest/path" "${vars[@]}"
```

## Contributing Templates

### Template Guidelines

When contributing templates:

1. **Clear Purpose** - Template solves specific use case
2. **Documentation** - README explains what and why
3. **Testing** - Tested with real projects
4. **Validation** - All YAML validates
5. **Maintenance** - Willing to maintain template

### Submission Process

1. Create template in `templates/yourtemplate/`
2. Add README.md to template directory
3. Update main README.md with template
4. Add tests if needed
5. Submit PR with description

## Future Template Ideas

Potential templates for the future:

- **swiftui** - SwiftUI-specific setup
- **clean** - Clean Architecture
- **spm** - Swift Package Manager
- **viper** - VIPER architecture
- **rxswift** - RxSwift reactive setup
- **combine** - Combine framework setup
- **minimal** - Bare minimum setup
- **enterprise** - Full enterprise setup

## Conclusion

The template system makes xcboot flexible and extensible. Create templates for your team's specific needs, share them with the community, and help xcboot support more project types!
