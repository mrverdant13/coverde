# Coverde

[![pub package][pub_badge]][pub_link]
[![License: MIT][license_badge]][license_link]
[![Dart CI][dart_ci_badge]][dart_ci_link]
[![codecov][codecov_badge]][codecov_link]
[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![melos][melos_badge]][melos_link]

A CLI for optimizing test execution and manipulating coverage trace files. Optimize tests, validate coverage, transform trace files, and generate HTML reports.

---

# Index

- [Installing](#installing)
- [Features](#features)
- [`coverde.yaml` configuration file](#coverdeyaml-configuration-file)
- [Usage with `melos`](#usage-with-melos)
- [CI integration for coverage checks](#ci-integration-for-coverage-checks)

---

# Installing

You can make `coverde` globally available by executing the following command:

```sh
$ dart pub global activate coverde
```

**NOTE:** To run `coverde` directly from the terminal, add the system cache `bin` directory to your `PATH` environment variable.

---

# Features
<!-- CLI FEATURES -->
- [**Optimize tests by gathering them.**](#coverde-optimize-tests)
- [**Check the coverage value (%) computed from a trace file.**](#coverde-check)
- [**Filter a coverage trace file.**](#coverde-filter)
- [**Transform a coverage trace file.**](#coverde-transform)
- [**Generate the coverage report from a trace file.**](#coverde-report)
- [**Remove a set of files and folders.**](#coverde-remove)
- [**Compute the coverage value (%) of an info file.**](#coverde-value)

## `coverde optimize-tests`

Optimize tests by gathering them.

> [!NOTE]
> **Why use `coverde optimize-tests`?**
>
> The `optimize-tests` command gathers all your Dart test files into a single "optimized" test entry point. This can lead to much faster test execution, especially in CI/CD pipelines or large test suites. By reducing the Dart VM spawn overhead and centralizing test discovery, it enables more efficient use of resources.
>
> For more information, see the [flutter/flutter#90225](https://github.com/flutter/flutter/issues/90225).

### Arguments

#### Single-options

- `--include`

  The glob pattern for the tests files to include.\
  **Default value:** `test/**_test.dart`

- `--exclude`

  The glob pattern for the tests files to exclude.

- `--output`

  The path to the optimized tests file.\
  **Default value:** `test/optimized_test.dart`

#### Flags

- `--flutter-goldens`

  Whether to use golden tests in case of a Flutter package.\
  **Default value:** _Enabled_

### Examples

#### Basic usage

Given the following test files:

**`test/user_test.dart`:**
```dart
import 'package:test/test.dart';

void main() {
  test('user test', () {
    // test implementation
  });
}
```

**`test/product_test.dart`:**
```dart
import 'package:test/test.dart';

void main() {
  test('product test', () {
    // test implementation
  });
}
```

Running:
```sh
$ coverde optimize-tests
```

**Output:** `test/optimized_test.dart`
```dart
// ignore_for_file: deprecated_member_use, type=lint

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:test_api/test_api.dart';

import 'product_test.dart' as _i1;
import 'user_test.dart' as _i2;

void main() {
  group(
    'product_test.dart',
    () {
      _i1.main();
    },
  );
  group(
    'user_test.dart',
    () {
      _i2.main();
    },
  );
}
```

#### Preserving Test Annotations

The command preserves test annotations from individual test files. Given the following test files with annotations:

**`test/slow_test.dart`:**
```dart
@Timeout(Duration(seconds: 45))
import 'package:test/test.dart';

void main() {
  test('slow test', () {
    // long-running test
  });
}
```

**`test/skipped_test.dart`:**
```dart
@Skip('Temporarily disabled')
import 'package:test/test.dart';

void main() {
  test('skipped test', () {
    // test implementation
  });
}
```

**`test/tagged_test.dart`:**
```dart
@Tags(['integration', 'slow'])
import 'package:test/test.dart';

void main() {
  test('tagged test', () {
    // test implementation
  });
}
```

**`test/vm_only_test.dart`:**
```dart
@TestOn('vm')
import 'package:test/test.dart';

void main() {
  test('VM-only test', () {
    // test implementation
  });
}
```

Running:
```sh
$ coverde optimize-tests --no-flutter-goldens
```

**Output:** `test/optimized_test.dart`
```dart
// ignore_for_file: deprecated_member_use, type=lint

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:test_api/test_api.dart';

import 'skipped_test.dart' as _i1;
import 'slow_test.dart' as _i2;
import 'tagged_test.dart' as _i3;
import 'vm_only_test.dart' as _i4;

void main() {
  group(
    'skipped_test.dart',
    () {
      _i1.main();
    },
    skip: 'Temporarily disabled',
  );
  group(
    'slow_test.dart',
    () {
      _i2.main();
    },
    timeout: Timeout(Duration(seconds: 45)),
  );
  group(
    'tagged_test.dart',
    () {
      _i3.main();
    },
    tags: ['integration', 'slow'],
  );
  group(
    'vm_only_test.dart',
    () {
      _i4.main();
    },
    testOn: 'vm',
  );
}
```

The following annotations are supported and preserved:
- `@Skip()` or `@Skip('reason')` → `skip: true` or `skip: 'reason'`
- `@Timeout(...)` → `timeout: Timeout(...)`
- `@Tags([...])` → `tags: [...]`
- `@TestOn('...')` → `testOn: '...'`
- `@OnPlatform({...})` → `onPlatform: {...}`

#### Excluding Test Files

To exclude certain test files using a glob pattern:

```sh
$ coverde optimize-tests --exclude "**/*_integration_test.dart"
```

This will gather all test files matching the default include pattern (`test/**_test.dart`) except those matching the exclude pattern.

#### Disabling Flutter Golden Tests

For non-Flutter packages or when golden tests are not needed:

```sh
$ coverde optimize-tests --no-flutter-goldens
```

This prevents the command from adding golden test setup code, which is only relevant for Flutter packages.


## `coverde check`

Check the coverage value (%) computed from a trace file.

The unique argument should be an integer between 0 and 100.\
This parameter indicates the minimum value for the coverage to be accepted.

### Arguments

#### Single-options

- `--input`

  Trace file used for the coverage check.\
  **Default value:** `coverage/lcov.info`

- `--file-coverage-log-level`

  The log level for the coverage value for each source file listed in the `input` info file.\
  **Default value:** `line-content`\
  **Allowed values:**
    - `none`: Log nothing.
    - `overview`: Log the overview of the coverage value for the file.
    - `line-numbers`: Log only the uncovered line numbers.
    - `line-content`: Log the uncovered line numbers and their content.

#### Parameters

- `min-coverage`

  The minimum coverage value to be accepted. It should be an integer between 0 and 100.

### Examples

![coverde-check-50.png](https://raw.githubusercontent.com/mrverdant13/coverde/main/packages/coverde_cli/doc/examples/terminal/coverde-check-50.png)
![coverde-check-file-coverage-log-level-line-numbers-100.png](https://raw.githubusercontent.com/mrverdant13/coverde/main/packages/coverde_cli/doc/examples/terminal/coverde-check-file-coverage-log-level-line-numbers-100.png)
![coverde-check-i-coverage-custom-lcov-info-file-coverage-log-level-none-75.png](https://raw.githubusercontent.com/mrverdant13/coverde/main/packages/coverde_cli/doc/examples/terminal/coverde-check-i-coverage-custom-lcov-info-file-coverage-log-level-none-75.png)


## `coverde filter`

> [!CAUTION]
> The `filter` command will be removed in the next major update. Use [`coverde transform`](#coverde-transform) instead.

Filter a coverage trace file.

Filter the coverage info by ignoring data related to files with paths that matches the given FILTERS.\
The coverage data is taken from the INPUT_LCOV_FILE file and the result is appended to the OUTPUT_LCOV_FILE file.

All the relative paths in the resulting coverage trace file will be resolved relative to the <base-directory>, if provided.

### Arguments

#### Single-options

- `--input`

  Origin coverage info file to pick coverage data from.\
  **Default value:** `coverage/lcov.info`

- `--output`

  Destination coverage info file to dump the resulting coverage data into.\
  **Default value:** `coverage/filtered.lcov.info`

- `--base-directory`

  Base directory relative to which trace file source paths are resolved.

- `--mode`

  The mode in which the OUTPUT_LCOV_FILE can be generated.\
  **Default value:** `a`\
  **Allowed values:**
    - `a`: Append filtered content to the OUTPUT_LCOV_FILE content, if any.
    - `w`: Override the OUTPUT_LCOV_FILE content, if any, with the filtered content.

#### Multi-options

- `--filters`

  Set of comma-separated path patterns of the files to be ignored.

  Each pattern must be a valid regex expression. Invalid patterns will cause the command to fail.\
  **Default value:** _None_

### Migration to `transform`

Use `coverde transform` with equivalent options:

| Filter option                   | Transform equivalent                                                                |
| ------------------------------- | ----------------------------------------------------------------------------------- |
| `--filters pattern1,pattern2`   | `--transformations skip-by-regex=pattern1 --transformations skip-by-regex=pattern2` |
| `--base-directory B`            | `--transformations relative=B`                                                      |
| `--input`, `--output`, `--mode` | Same options                                                                        |

Example:

```sh
# Before (filter)
coverde filter --input coverage/lcov.info --output coverage/filtered.lcov.info \
  --filters '\.g\.dart$' --base-directory /project --mode w

# After (transform)
coverde transform --input coverage/lcov.info --output coverage/filtered.lcov.info \
  --transformations skip-by-regex='\.g\.dart$' --transformations relative=/project --mode w
```


## `coverde transform`

Transform a coverage trace file.

Apply a sequence of transformations to the coverage data.\
The coverage data is taken from the INPUT_LCOV_FILE file and written to the OUTPUT_LCOV_FILE file.

Presets can be defined in coverde.yaml under the `transformations` key.

### Arguments

#### Single-options

- `--input`

  Origin coverage info file to transform.\
  **Default value:** `coverage/lcov.info`

- `--output`

  Destination coverage info file to dump the transformed coverage data into.\
  **Default value:** `coverage/transformed.lcov.info`

- `--mode`

  The mode in which the OUTPUT_LCOV_FILE can be generated.\
  **Default value:** `a`\
  **Allowed values:**
    - `a`: Append transformed content to the OUTPUT_LCOV_FILE content, if any.
    - `w`: Override the OUTPUT_LCOV_FILE content, if any, with the transformed content.

#### Multi-options

- `--transformations`

  Transformation steps to apply in order.\
  **Default value:** _None_\
  **Allowed values:**
    - `keep-by-regex=<regex>`: Keep files that match the `<regex>`.
    - `skip-by-regex=<regex>`: Skip files that match the `<regex>`.
    - `keep-by-glob=<glob>`: Keep files that match the `<glob>`.
    - `skip-by-glob=<glob>`: Skip files that match the `<glob>`.
    - `keep-by-coverage=<comparison>`: Keep files that match the `<comparison>` (with reference values between 0 and 100).
    - `skip-by-coverage=<comparison>`: Skip files that match the `<comparison>` (with reference values between 0 and 100).
    - `relative=<base-path>`: Rewrite file paths to be relative to the `<base-path>`.
    - `preset=<name>`: Expand a preset from `coverde.yaml`.

#### Flags

- `--explain`

  Print the resolved transformation list and exit without modifying files.\
  **Default value:** _Disabled_

### Examples

#### Inline Transformations

```sh
$ coverde transform \
  --transformations relative="/packages/my_package/" \
  --transformations keep-by-glob="lib/**" \
  --transformations skip-by-glob="**/*.g.dart" \
  --transformations keep-by-coverage="lte|80"
```

This transformation chain performs the following steps:
1. Rewrite file paths to be relative to the `/packages/my_package/` directory (useful for monorepos).
2. Keep files that match the `lib/**` glob pattern, i.e. implementation files.
3. Skip files that match the `**/*.g.dart` glob pattern, i.e. generated files.
4. Keep files that have a coverage value less than or equal to 80%.

#### Preset Usage

Given the following `coverde.yaml` configuration:

```yaml
# coverde.yaml

transformations:
  implementation-without-generated:
    - type: keep-by-glob
      glob: "lib/**"
    - type: skip-by-glob
      glob: "**/*.g.dart"
```

Running:

```sh
$ coverde transform \
  --transformations relative="/packages/my_package/" \
  --transformations preset=implementation-without-generated \
  --transformations keep-by-coverage="lte|80"
```

Is equivalent to the [Inline Transformations](#inline-transformations) example.


## `coverde report`

Generate the coverage report from a trace file.

Generate the coverage report inside REPORT_DIR from the TRACE_FILE trace file.

### Arguments

#### Single-options

- `--input`

  Coverage trace file to be used for the coverage report generation.\
  **Default value:** `coverage/lcov.info`

- `--output`

  Destination directory where the generated coverage report will be stored.\
  **Default value:** `coverage/html/`

- `--medium`

  Medium threshold.

  Must be a number between 0 and 100, and must be less than the high threshold.\
  **Default value:** `75`

- `--high`

  High threshold.

  Must be a number between 0 and 100, and must be greater than the medium threshold.\
  **Default value:** `90`

#### Flags

- `--launch`

  Launch the generated report in the default browser.
  This option is only supported on desktop platforms.
  (defaults to off)\
  **Default value:** _Disabled_

### Examples

![coverde-report-dir.png](https://raw.githubusercontent.com/mrverdant13/coverde/main/packages/coverde_cli/doc/examples/browser/coverde-report-dir.png)
![coverde-report-file.png](https://raw.githubusercontent.com/mrverdant13/coverde/main/packages/coverde_cli/doc/examples/browser/coverde-report-file.png)


## `coverde remove`

Remove a set of files and folders.

### Arguments

#### Flags

- `--dry-run`

  Preview what would be deleted without actually deleting.
  When enabled (default), the command will list what would be deleted but not perform the deletion.
  When disabled, the command will actually delete the specified files and folders.\
  **Default value:** _Enabled_

- `--accept-absence`

  Accept absence of a file or folder.
  When an element is not present:
  - If enabled, the command will continue.
  - If disabled, the command will fail.\
  **Default value:** _Enabled_

#### Parameters

- `paths`

  Set of file and/or directory paths to be removed.


## `coverde value`

Compute the coverage value (%) of an info file.

Compute the coverage value of the LCOV_FILE info file.

### Arguments

#### Single-options

- `--input`

  Coverage info file to be used for the coverage value computation.\
  **Default value:** `coverage/lcov.info`

- `--file-coverage-log-level`

  The log level for the coverage value for each source file listed in the LCOV_FILE info file.\
  **Default value:** `line-content`\
  **Allowed values:**
    - `none`: Log nothing.
    - `overview`: Log the overview of the coverage value for the file.
    - `line-numbers`: Log only the uncovered line numbers.
    - `line-content`: Log the uncovered line numbers and their content.

### Examples

![coverde-value-file-coverage-log-level-line-numbers.png](https://raw.githubusercontent.com/mrverdant13/coverde/main/packages/coverde_cli/doc/examples/terminal/coverde-value-file-coverage-log-level-line-numbers.png)
![coverde-value-i-coverage-custom-lcov-info-file-coverage-log-level-none.png](https://raw.githubusercontent.com/mrverdant13/coverde/main/packages/coverde_cli/doc/examples/terminal/coverde-value-i-coverage-custom-lcov-info-file-coverage-log-level-none.png)
![coverde-value.png](https://raw.githubusercontent.com/mrverdant13/coverde/main/packages/coverde_cli/doc/examples/terminal/coverde-value.png)
<!-- CLI FEATURES -->

---

# `coverde.yaml` configuration file

The `coverde.yaml` file allows you to define reusable transformation presets for the [`coverde transform`](#coverde-transform) command.

The file is optional and is read from the **current working directory** when you run `coverde transform` (typically your project root).

## File Format

The configuration file uses YAML format with a `transformations` key at the root level. Each preset is defined as a named list of transformation steps.

```yaml
# coverde.yaml

transformations:
  preset-name:
    - type: <transformation-type>
      <parameter-1-name>: <value-1>
      <parameter-2-name>: <value-2>
    - type: <transformation-type>
      <parameter-1-name>: <value-1>
```

## Transformation Types

Each transformation step requires a `type` field and the corresponding parameters.

### `keep-by-regex`

Keep files whose paths match the provided regular expression pattern.

```yaml
type: keep-by-regex
regex: <regex-pattern>  # Example: "^lib/.*\\.dart$"
```

### `skip-by-regex`

Skip (exclude) files whose paths match the provided regular expression pattern.

```yaml
type: skip-by-regex
regex: <regex-pattern>  # Example: "^test/.*_integration\\.dart$"
```

### `keep-by-glob`

Keep files whose paths match the provided glob pattern.

```yaml
type: keep-by-glob
glob: <glob-pattern>  # Example: "**/lib/**"
```

### `skip-by-glob`

Skip (exclude) files whose paths match the provided glob pattern.

```yaml
type: skip-by-glob
glob: <glob-pattern>  # Example: "**/*.g.dart"
```

### `keep-by-coverage`

Keep files whose coverage meets the specified comparison.

```yaml
type: keep-by-coverage
comparison: <comparison>  # Example: "lte|80" (less than or equal to 80%)
```

### `skip-by-coverage`

Skip (exclude) files whose coverage meets the specified comparison.

```yaml
type: skip-by-coverage
comparison: <comparison>  # Example: "gt|50" (greater than 50%)
```

See [Comparison Operators](#comparison-operators) for the allowed comparison operators.

### `relative`

Rewrite file paths so that they are relative to the given base path.

```yaml
type: relative
base-path: <base-path>  # Example: "/path/to/project"
```

### `preset`

Include transformations defined in another preset by name.

> [!CAUTION]
> Circular references between presets are detected and will result in an error.


```yaml
type: preset
name: <other-preset-name>  # Example: "production-only"
```

## Comparison Operators

### `eq`

`eq|<value>`

Checks if the value is equal to `<value>`.

### `neq`

`neq|<value>`

Checks if the value is not equal to `<value>`.

### `gt`

`gt|<value>`

Checks if the value is greater than `<value>`.

### `gte`

`gte|<value>`

Checks if the value is greater than or equal to `<value>`.

### `lt`

`lt|<value>`

Checks if the value is less than `<value>`.

### `lte`

`lte|<value>`

Checks if the value is less than or equal to `<value>`.

### `in`

`in|<range>`

Checks if the value is within the specified `<range>`.

The `<range>` can be one of the following:
- `[lowerValue,upperValue]`
- `(lowerValue,upperValue]`
- `[lowerValue,upperValue)`
- `(lowerValue,upperValue)`

The `[` and `]` brackets indicate that the lower and upper bounds are inclusive, while the `(` and `)` parentheses indicate that the lower and upper bounds are exclusive.

Both lower and upper bounds should be between 0 and 100 inclusive, as they are coverage percentages.

## Example Configuration

```yaml
# coverde.yaml

transformations:
  # Exclude generated code files
  exclude-generated:
    - type: skip-by-glob
      glob: "**/*.g.dart"
    - type: skip-by-glob
      glob: "**/*.freezed.dart"
    - type: skip-by-glob
      glob: "**/*.gen.dart"

  # Keep only production code (lib folder), excluding generated files
  production-only:
    - type: keep-by-glob
      glob: "**/lib/**"
    - type: preset
      name: exclude-generated

  # Filter to files with high coverage
  high-coverage-only:
    - type: keep-by-coverage
      comparison: "gte|80"

  # Common CI workflow preset
  ci-workflow:
    - type: preset
      name: production-only
    - type: relative
      base-path: "/path/to/project"
```

## Using Presets

Once defined, presets can be used with the `coverde transform` command.

```sh
# Use a single preset
$ coverde transform --transformations preset=exclude-generated

# Combine presets with inline transformations
$ coverde transform \
  --transformations preset=production-only \
  --transformations skip-by-coverage="gt|50"

# Preview transformations without applying them
$ coverde transform --transformations preset=ci-workflow --explain
```

---

# Update checks

If `coverde` is installed via `dart pub global activate --source=hosted`, i.e. as a global package from the Pub.dev, it can prompt the user to update the package if a new compatible version is available.

This process verifies that the new release has a higher SemVer version than the current one, and that its environment constraints are met by the current Dart SDK.

<!-- UPDATE CHECKS -->
`--update-check`

The update check mode to use.\
**Default value:** `enabled`\
**Allowed values:**
  - `disabled`: Disable the update check.
  - `enabled`: Enable the update check with silent output, only prompting the user if an update is available, and ignoring any warnings and errors.
  - `enabled-verbose`: Enable the update check with verbose output.
<!-- UPDATE CHECKS -->

---

# Usage with [melos][melos_link]

If your project uses `melos` to manage its multi-package structure, `coverde` can help optimize test execution and collect test coverage data in a unified trace file.

Here are some examples of how to use `coverde` with `melos` to manage your monorepo. Adapt them to match your project structure and needs.

## Test Optimization

Optimize test execution by gathering all test files into a single optimized test file before running tests:

```yaml
test:
  description: Run tests and generate coverage trace file for a package
  run: >
    dart run coverde optimize-tests
    --output=test/optimized_test.dart
    &&
    dart test
    --coverage-path=coverage/lcov.info
    --test-randomize-ordering-seed random
    test/optimized_test.dart
  packageFilters:
    dependsOn:
      - test
    dirExists:
      - test
```

This script:
1. Optimizes tests by gathering them into a single file
2. Runs the optimized test file with coverage collection, directly outputting an LCOV trace file

## Coverage Data Merging

Merge coverage trace files from all packages into a unified trace file:

```yaml
coverage.merge:
  description: Merge all packages coverage trace files
  run: >
    dart run coverde rm
    --no-dry-run
    MELOS_ROOT_PATH/coverage/filtered.lcov.info
    &&
    melos exec
    --file-exists coverage/lcov.info
    --
    "
    dart run coverde transform
    --input coverage/lcov.info
    --output MELOS_ROOT_PATH/coverage/filtered.lcov.info
    --transformations relative=MELOS_ROOT_PATH
    --transformations skip-by-glob='**/*.g.dart'
    "
```

This script:
1. Removes any existing merged coverage file
2. Executes `coverde transform` for each package that contains a `coverage/lcov.info` file:
   - Rewrites file paths to be relative to the monorepo root (using Melos’s `MELOS_ROOT_PATH` environment variable)
   - Skips files that match the `**/*.g.dart` glob pattern, i.e. generated files.

The resulting merged trace file can be used with `coverde report` to generate a unified HTML coverage report for the entire monorepo, or with `coverde check` to validate the coverage threshold for the overall project.

## Coverage Check

Validate minimum coverage threshold across all packages:

```yaml
coverage.check:
  description: Check test coverage
  run: >
    dart run coverde check
    --input MELOS_ROOT_PATH/coverage/filtered.lcov.info
    100
```

This script checks that the merged coverage trace file meets the minimum coverage threshold (100% in this example). The command will fail if coverage is below the threshold, making it suitable for CI/CD pipelines.

---

# CI integration for coverage checks

If your project uses GitHub Actions for CI, you might already know [very_good_coverage][very_good_coverage_link], which offers a simple but effective method for coverage validation.

However, adding coverage checks to CI workflows hosted by other alternatives is not always that straightforward.

To solve this, after enabling Dart or Flutter in your CI workflow, according to your project requirements, you can use `coverde` and its `check` tool by adding the following commands to your workflow steps:

- `dart pub global activate coverde`
- `coverde check <min_coverage>`

# Bugs or Requests

If you encounter any problems or you believe the CLI is missing a feature, feel free to [open an issue on GitHub][open_issue_link].

Pull requests are also welcome. See [CONTRIBUTING.md][_docs_contributing_link].

[_docs_contributing_link]: https://github.com/mrverdant13/coverde/blob/main/CONTRIBUTING.md
[_docs_coverde_check_example_1]: https://github.com/mrverdant13/coverde/blob/main/packages/coverde_cli/doc/check_result_pass.png?raw=true
[_docs_coverde_check_example_2]: https://github.com/mrverdant13/coverde/blob/main/packages/coverde_cli/doc/check_result_fail.png?raw=true
[_docs_coverde_report_example_1]: https://github.com/mrverdant13/coverde/blob/main/packages/coverde_cli/doc/report_directory_example.png?raw=true
[_docs_coverde_report_example_2]: https://github.com/mrverdant13/coverde/blob/main/packages/coverde_cli/doc/report_file_example.png?raw=true
[codecov_badge]: https://codecov.io/gh/mrverdant13/coverde/branch/main/graph/badge.svg
[codecov_link]: https://codecov.io/gh/mrverdant13/coverde
[dart_ci_badge]: https://github.com/mrverdant13/coverde/actions/workflows/ci.yaml/badge.svg?branch=main
[dart_ci_link]: https://github.com/mrverdant13/coverde/actions?query=workflow%3A%22Dart+CI%22
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[melos_badge]: https://img.shields.io/badge/maintained%20with-melos-f700ff.svg
[melos_link]: https://melos.invertase.dev/
[open_issue_link]: https://github.com/mrverdant13/coverde/issues/new
[pub_badge]: https://img.shields.io/pub/v/coverde.svg
[pub_link]: https://pub.dev/packages/coverde
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://github.com/VeryGoodOpenSource/very_good_analysis
[very_good_coverage_link]: https://github.com/VeryGoodOpenSource/very_good_coverage
