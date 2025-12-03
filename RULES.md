# bash-tools Development Rules

## Project Overview

**bash-tools** is an **infrastructure/library** project providing reusable Bash utilities, a bundler, and a testing framework. This project focuses on modularity, reusability, and comprehensive documentation.

## Coding Style & Conventions

### Function Naming

- Use `namespace.function()` pattern (e.g., `array.contains`, `log.info`, `folder.create`)
- Namespace should match the module/file name
- Function names should be descriptive and use camelCase

**Examples:**
```bash
array.contains()
log.info()
folder.create()
string.replace()
```

### Function Documentation

All public functions **MUST** have documentation blocks using this format:

```bash
## @function: namespace.function(param1, param2?)
##
## @description: Clear description of what the function does
##
## @param: $1 - Parameter description
## @param: $2 - Optional parameter description (use ? to indicate optional)
##
## @return: Description of return value or void
##
## @example: namespace.function "arg1" "arg2"
##
## @note: Important implementation details (if needed)
##
## @dependencies: List required modules (if any)
```

**Required fields:**
- `@function` - Function signature
- `@description` - What the function does
- `@param` - Each parameter (use `?` for optional)
- `@return` - Return value description or "void"

**Optional fields:**
- `@example` - Usage example (recommended for complex functions)
- `@note` - Important implementation details
- `@dependencies` - Required modules

### Error Handling

- Use `error.throw(message, code)` for fatal errors that should stop execution
- Use `log.warning()` for recoverable issues
- Validate inputs at function boundaries
- Provide clear error messages with context

**Example:**
```bash
if [[ ! -f "$file" ]]; then
  error.throw "File not found: $file" 1
fi
```

### Logging

Use appropriate log levels:

- `log.verbose()` - Very detailed debugging information
- `log.debug()` - Debug information for development
- `log.info()` - General informational messages
- `log.warning()` - Warning messages for recoverable issues
- `log.error()` - Error messages (use `error.throw()` for fatal errors)

### Variable Naming

- Use descriptive names
- Prefer local variables: `local var_name="$1"`
- Use UPPER_CASE for constants/globals only
- Avoid global namespace pollution

### Shebang

All executable scripts **MUST** start with `#!/bin/bash`

## File Structure

### Source Organization

```
bash-tools/
├── src/
│   ├── main/              # Source code
│   │   ├── module-name/
│   │   │   ├── bundle.module-name.sh
│   │   │   ├── cli.sh
│   │   │   └── module.sh
│   │   └── ...
│   └── test/              # Test files
│       └── module-name/
│           └── module.test.sh
├── dist/                 # Generated bundles
├── VERSION               # Semantic version
└── release.sh           # Release script
```

### Module Structure

Each module should be self-contained in its own directory:

- `bundle.*.sh` - Bundle entrypoint (if needed)
- `cli.sh` - CLI interface (if needed)
- `module.sh` - Main module code

## Import/Source Patterns

### Preferred Import Method

Use `import` function for relative imports:

```bash
import "../core/logger.sh"
import "../tools/error.sh"
```

### Source Pattern

For absolute paths or when import is not available:

```bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/importer.sh"
```

### Import Order

1. First: Import `importer.sh` if using `import` function
2. Then: Import dependencies in logical order
3. Last: Import the module's own dependencies

### Avoid

- Circular dependencies
- Global `source` without path resolution
- Hardcoded absolute paths

## Testing Requirements

### Test File Structure

- Test files: `*.test.sh` in `src/test/`
- Test files should mirror `src/main/` structure
- Example: `src/main/tools/string.sh` → `src/test/tools/string.test.sh`

### Test Function Naming

- Test functions: Named `test_*` (e.g., `test_string_contains_success`)
- Use descriptive names that explain what is being tested

### Test Framework

Use `expect` framework for assertions:

```bash
expect "$result" to.equal "expected"
expect "$result" to.contain "substring"
expect "$result" to.be.empty
expect "$result" to.have.length 5
expect.run "command" to.fail.with 1 "error message"
```

### Lifecycle Hooks

Use when needed:

- `before()` - Setup before all tests
- `before_each()` - Setup before each test
- `after_each()` - Cleanup after each test
- `after()` - Cleanup after all tests

### Test Requirements

- All public functions should have test coverage
- Tests must pass before any release
- Run tests with: `bash src/main/bash-it/runner.sh`

## Bundling Process

### Bundle Entrypoints

- Any `bundle.*.sh` file in `src/main/` is a bundle entrypoint
- Bundle name is derived from filename: `bundle.tools.sh` → `tools`

### Bundle Structure

Bundles should:

1. Load dependencies via `import` or `source`
2. Define the main entry function
3. Call the entry function with `"$@"` to pass arguments

**Example:**
```bash
#!/bin/bash

source <(curl -fsSL https://github.com/nu-art/bash-tools/releases/latest/download/bundle.loader.sh) -b lib.tools -f

import "./module.sh"

module.run "$@"
```

### Bundler Behavior

- Automatically resolves `import` and `source` statements recursively
- Generated bundles go to `dist/bundle.*.sh`
- Bundles include version metadata and generation timestamp
- Strips import/source statements and reorders for dependency correctness

### Bundle Usage

Bundles are distributed via GitHub releases and can be loaded:

```bash
source <(curl -fsSL https://github.com/nu-art/bash-tools/releases/latest/download/bundle.loader.sh) -b tools
```

## Release Process

Follow this exact sequence:

1. **Run tests**: `release.run_tests`
2. **Bundle artifacts**: `release.bundle`
3. **Bump version**: `release.bump_version <type>` (patch/minor/major)
4. **Commit version bump**: `release.commit_version_bump`
5. **Tag version**: `release.tag_current_version`
6. **Publish to GitHub**: `release.publish_github`

Execute via: `bash release.sh`

## Version Management

### Semantic Versioning

- Format: `MAJOR.MINOR.PATCH` (e.g., `0.2.6`)
- **Patch**: Bug fixes (backward compatible)
- **Minor**: New features (backward compatible)
- **Major**: Breaking changes

### Version File

- Stored in `VERSION` file at project root
- Single line with version number only
- Updated automatically during release process

## Documentation Standards

### Function Documentation

All public functions **MUST** include:

- `## @function:` - Function signature
- `## @description:` - What the function does
- `## @param:` - Each parameter (use `?` for optional)
- `## @return:` - Return value description or "void"
- `## @example:` - Usage example (for complex functions)
- `## @note:` - Important implementation details (if needed)
- `## @dependencies:` - Required modules (if any)

### Code Comments

- Comment complex logic, but prefer self-documenting code
- Use `#` for inline comments
- Use `##` for documentation blocks

## Code Quality

### Best Practices

- Use `set -e` in scripts that should fail on errors
- Prefer early returns over deep nesting
- Use local variables to avoid global namespace pollution
- Validate function inputs
- Handle edge cases explicitly

### Code Organization

- Group related functions together
- Keep functions focused and single-purpose
- Avoid deep nesting (max 3-4 levels)
- Use helper functions for complex logic

## Project-Specific Guidelines

### Infrastructure Focus

- Focus on reusable, modular utilities
- Each utility module should be self-contained
- Provide comprehensive documentation
- Maintain backward compatibility when possible
- Test coverage for all public functions
- Consider performance for frequently-used utilities

### Module Design

- One module per file/directory
- Clear separation of concerns
- Minimal dependencies between modules
- Use dependency injection patterns when appropriate

## Common Patterns

### Path Resolution

```bash
local REPO_ROOT
REPO_ROOT="$(folder.repo_root)"
```

### Function with Optional Parameters

```bash
function.name() {
  local required="$1"
  local optional="${2:-default_value}"
  # function body
}
```

### Array Operations

Use array utilities from `tools/array.sh`:

- `array.contains(item, ...list)`
- `array.map(fromArray, toArray, mapperFn)`
- `array.forEach(arrayName, consumerFn)`

### Error Handling Pattern

```bash
if [[ ! -f "$file" ]]; then
  error.throw "File not found: $file" 1
fi
```

