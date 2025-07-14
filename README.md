# bash-tools

Modular Bash utilities and test framework for building, testing, and bundling shell scripts with confidence.

## Overview

`bash-tools` is a lightweight framework for authoring clean, testable Bash scripts.
It brings the best of development discipline to shell environments: fluent assertions, modular utilities, and deterministic bundling.

Whether you're writing CI hooks, release scripts, or project scaffolding tools, this framework helps you:

* Avoid repetition with reusable utilities (`array`, `file`, `string`, etc.)
* Validate behavior using `expect` and a Mocha-style test layout
* Flatten source trees into distributable bundles
* Run structured tests with TAP output

## Key Features

### 🔧 Tools

A set of focused utility modules for common scripting needs:

* **Array utils**: `array.contains`, `array.remove`, `array.map`, etc.
* **String ops**: `string.replace`, `string.trim`, `string.split`, etc.
* **File ops**: `file.exists`, `file.read`, `file.write`, etc.
* **Git tools**: helpers for common git workflows
* **File system**: folder creation, navigation logic
* **Logger**: level-based logging with color support


#### 📦 Bundler

The bundler flattens the tools and test infrastructure into a portable, standalone script:

* Entry point: any `bundle.<name>.sh` file under `src/main`
* Automatically resolves all `source $ROOT/...` calls recursively
* Generates `dist/bundle.<name>.sh`
* Strips comments and reorders for deep-first correctness

#### Integration - Example
```bash
#!/bin/bash
# ./integration.sh
set -e

LOADER_URL="https://github.com/nu-art/bash-tools/releases/latest/download/bundle.loader.sh"
LOADER_PATH="/tmp/bash-tools.loader.$$"
CACHE_DIR="$HOME/.cache"
CACHE_PATH="$CACHE_DIR/bash-utils.sh"

mkdir -p "$CACHE_DIR"
curl -fsSL "$LOADER_URL" -o "$LOADER_PATH"
chmod +x "$LOADER_PATH"

bash "$LOADER_PATH" --bundle=tools --target="$CACHE_PATH"

source "$CACHE_PATH"
string.join "-" hello world
```

### ✅ Testing (`bash-it`)

Bash doesn't have a native test runner. This framework introduces:

* `expect` and `expect.run` for fluent assertions
* Support for:

    * `to.equal`, `to.contain`, `to.match`
    * `to.be.empty`, `to.have.length`, `to.fail.with`, etc.
* Lifecycle hooks:

    * `before`, `before_each`, `after_each`, `after`
* TAP-compatible output
* Filters:

    * `--file <filter>` — run tests from matching files
    * `--grep <regex>` — run tests matching name pattern
    * `--out <file>` — pipe TAP to a file

```bash
expect "result" to.equal "expected"
expect.run "ls non-existent" to.fail.with 1 "No such file"
```

Test discovery runs all `test_*` functions from `*.test.sh` files.

#### Bash-IT - Example
```bash
# Create a test file: my-script.test.sh

before() {
  # optional setup
}

before_each() {
  # optional per-test setup
}

after_each() {
  # optional per-test cleanup
}

after() {
  # optional teardown
}

test_assert_the_answer_to_the_ultimate_question_of_life_the_universe_and_everything(){
  expect "42" to.equal "42"
}
```

Run all tests:

```bash
bash src/main/bash-it/tests-runner.sh
```

Filter specific ones:

```bash
bash src/main/bash-it/tests-runner.sh --file=git --grep=commit
```