# Coverde

[![pub package][pub_badge]][pub_link]
[![License: MIT][license_badge]][license_link]
[![Dart CI][dart_ci_badge]][dart_ci_link]
[![codecov][codecov_badge]][codecov_link]
[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]

A CLI for optimizing test execution and manipulating coverage trace files. Optimize tests, validate coverage, transform trace files, and generate HTML reports.

---

# Index

- [Installing](#installing)
- [Features](#features)
- [`coverde.yaml` configuration file](#coverdeyaml-configuration-file)
- [Monorepo coverage](#monorepo-coverage)

---

# Installing

Make `coverde` globally available with:

```sh
$ dart install coverde
```

`dart install` requires Dart 3.10 or later. To run `coverde` directly from the terminal, add its `bin` directory to your `PATH` environment variable:

- **macOS:** `$HOME/Library/Application Support/Dart/install/bin`
- **Linux:** `$HOME/.local/share/dart/install/bin`, or `$XDG_DATA_HOME/dart/install/bin` when `XDG_DATA_HOME` is set
- **Windows:** `%LOCALAPPDATA%\Dart\install\bin`

`DART_DATA_HOME` changes this location. The `bin` directory is then `$DART_DATA_HOME/install/bin`.

These directories are the defaults from [Packaging and distributing Dart CLI tools][dart_cli_distribution_link].

<details>
<summary>Use `dart pub global activate` instead</summary>

> [!NOTE]
> `dart install` is preferred.

```sh
$ dart pub global activate coverde
```

This installs a `coverde` executable in the pub cache `bin` directory:

- **macOS or Linux:** `$HOME/.pub-cache/bin`
- **Windows:** `%LOCALAPPDATA%\Pub\Cache\bin`

`PUB_CACHE` changes this location. The `bin` directory is then `$PUB_CACHE/bin`.

</details>

---

# Features
<!-- CLI FEATURES -->
- [**Optimize tests by gathering them.**](#coverde-optimize-tests)
- [**Check the coverage value (%) computed from a trace file.**](#coverde-check)
- [**Filter a coverage trace file.**](#coverde-filter)
- [**Transform a coverage trace file.**](#coverde-transform)
- [**Generate the coverage report from a trace file.**](#coverde-report)
- [**Render a named coverage report from a trace file.**](#coverde-render)
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

- `--total-shards`

  The total number of shards to split tests across. Requires `--shard-index` to also be specified.

- `--shard-index`

  The index of the current shard (0-based). Requires `--total-shards` to also be specified.

#### Flags

- `--flutter-goldens`

  Whether to use golden tests in case of a Flutter package.\
  **Default value:** _Enabled_

### Examples

<details>
<summary>Basic usage</summary>

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

</details>

<details>
<summary>Preserving Test Annotations</summary>

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

</details>

<details>
<summary>Excluding Test Files</summary>

#### Excluding Test Files

To exclude certain test files using a glob pattern:

```sh
$ coverde optimize-tests --exclude "**/*_integration_test.dart"
```

This will gather all test files matching the default include pattern (`test/**_test.dart`) except those matching the exclude pattern.

</details>

<details>
<summary>Disabling Flutter Golden Tests</summary>

#### Disabling Flutter Golden Tests

For non-Flutter packages or when golden tests are not needed:

```sh
$ coverde optimize-tests --no-flutter-goldens
```

This prevents the command from adding golden test setup code, which is only relevant for Flutter packages.

</details>

<details>
<summary>Sharding Tests</summary>

#### Sharding Tests

For large test suites, you can split tests across multiple shards to run them in parallel in different processes or CI jobs. Sharding requires both `--total-shards` and `--shard-index` options to be specified together.

**Example:** Splitting 4 test files across 2 shards

Given the following test files (sorted alphabetically):
- `test/auth_test.dart` (index 0)
- `test/order_test.dart` (index 1)
- `test/product_test.dart` (index 2)
- `test/user_test.dart` (index 3)

Tests are distributed using round-robin assignment by index: `index % <total shards> == <shard index>`.

To run shard 0 (gets indices 0 and 2):

```sh
$ coverde optimize-tests --total-shards=2 --shard-index=0 --output=test/optimized_test_shard_0.dart
```

**Output:** `test/optimized_test_shard_0.dart`
```dart
// ignore_for_file: deprecated_member_use, type=lint

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:test_api/test_api.dart';

import 'auth_test.dart' as _i1;
import 'product_test.dart' as _i2;

void main() {
  group(
    'auth_test.dart',
    () {
      _i1.main();
    },
  );
  group(
    'product_test.dart',
    () {
      _i2.main();
    },
  );
}
```

To run shard 1 (gets indices 1 and 3):

```sh
$ coverde optimize-tests --total-shards=2 --shard-index=1 --output=test/optimized_test_shard_1.dart
```

**Output:** `test/optimized_test_shard_1.dart`
```dart
// ignore_for_file: deprecated_member_use, type=lint

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:test_api/test_api.dart';

import 'order_test.dart' as _i1;
import 'user_test.dart' as _i2;

void main() {
  group(
    'order_test.dart',
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

In a CI/CD pipeline, you could run both shards in parallel:

```sh
# Job 1
$ dart test test/optimized_test_shard_0.dart

# Job 2 (running concurrently)
$ dart test test/optimized_test_shard_1.dart
```

**Sharding with 3 shards:**

```sh
# Shard 0
$ coverde optimize-tests --total-shards=3 --shard-index=0 --output=test/optimized_test_0.dart

# Shard 1
$ coverde optimize-tests --total-shards=3 --shard-index=1 --output=test/optimized_test_1.dart

# Shard 2
$ coverde optimize-tests --total-shards=3 --shard-index=2 --output=test/optimized_test_2.dart
```

**Notes:**
- Shard indices are 0-based (start from 0)
- The `--shard-index` must be less than `--total-shards`
- Tests are distributed as evenly as possible across shards
- Both `--total-shards` and `--shard-index` must be provided together; specifying only one will result in an error

</details>


## `coverde check`

Check the coverage value (%) computed from a trace file.

The unique argument is a coverage threshold.\
It is either a number between 0 and 100, or the name of a `coverage` entry in coverde.yaml.

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

  A number between 0 and 100, or the name of a `coverage` entry in coverde.yaml.

### Examples

<details>
<summary>Show uncovered source</summary>

![coverde-check-50.png](https://raw.githubusercontent.com/mrverdant13/coverde/main/packages/coverde_cli/doc/examples/terminal/coverde-check-50.png)

</details>

<details>
<summary>Show uncovered line numbers only</summary>

![coverde-check-file-coverage-log-level-line-numbers-100.png](https://raw.githubusercontent.com/mrverdant13/coverde/main/packages/coverde_cli/doc/examples/terminal/coverde-check-file-coverage-log-level-line-numbers-100.png)

</details>

<details>
<summary>Show resulting coverage only</summary>

![coverde-check-i-coverage-custom-lcov-info-file-coverage-log-level-none-75.png](https://raw.githubusercontent.com/mrverdant13/coverde/main/packages/coverde_cli/doc/examples/terminal/coverde-check-i-coverage-custom-lcov-info-file-coverage-log-level-none-75.png)

</details>


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

  Transformation steps to apply in order.
  Repeat this option for each step. A value may contain commas.\
  **Default value:** _None_\
  **Allowed values:**
    - `keep-by-regex=<regex>`: Keep files that match the `<regex>`.
    - `skip-by-regex=<regex>`: Skip files that match the `<regex>`.
    - `keep-by-glob=<glob>`: Keep files that match the `<glob>`.
    - `skip-by-glob=<glob>`: Skip files that match the `<glob>`.
    - `keep-by-coverage=<comparison>`: Keep files that match the `<comparison>` (with reference values between 0 and 100).
    - `skip-by-coverage=<comparison>`: Skip files that match the `<comparison>` (with reference values between 0 and 100).
    - `relative=<base-path>`: Rewrite file paths to be relative to the `<base-path>`.
    - `preset=<name>`: Expand the `<name>` preset from `coverde.yaml`.
    - `preset={name: <name>, file: <file>}`: Expand the `<name>` preset from the `coverde.yaml` at `<file>`.

#### Flags

- `--explain`

  Print the resolved transformation list and exit without modifying files.\
  **Default value:** _Disabled_

### Examples

<details>
<summary>Inline Transformations</summary>

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

</details>

<details>
<summary>Preset Usage</summary>

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

</details>

<details>
<summary>Preset from another file</summary>

#### Preset from another file

A plain `preset` value is a name in the working directory's `coverde.yaml`. A YAML map with `file` loads that name from another file. Quote a path or name that contains `:` or `#`.

```sh
$ coverde transform \
  --transformations 'preset={file: ../coverde.yaml, name: ci-workflow}'
```

The same preset can be cited from a package `coverde.yaml`. `file` is relative to the yaml file that contains the step:

```yaml
# packages/my_package/coverde.yaml

transformations:
  package:
    - type: preset
      file: ../coverde.yaml
      name: ci-workflow
```

```sh
$ coverde transform --transformations preset=package
```

</details>


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


## `coverde render`

Render a named coverage report from a trace file.

The report is selected from the reports defined in coverde.yaml.

### Arguments

#### Multi-options

- `--input`

  Coverage trace file to render.

  Repeat to merge traces. Records with the same path are merged.
  The trace time is the latest modification time.\
  **Default value:** `coverage/lcov.info`

- `--variable`

  A name=value pair exposed to the template as variables["name"].

  Repeat to set more than one variable. A later copy of the same name wins.\
  **Default value:** _None_

#### Single-options

- `--report`

  Name of the report defined in coverde.yaml.

  Required when coverde.yaml defines more than one report.
  When it defines one report, that report is used.

- `--config`

  Path to the coverde.yaml file.

  Relative report paths resolve from that file's directory.\
  **Default value:** `coverde.yaml`


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

<details>
<summary>Show uncovered source</summary>

![coverde-value.png](https://raw.githubusercontent.com/mrverdant13/coverde/main/packages/coverde_cli/doc/examples/terminal/coverde-value.png)

</details>

<details>
<summary>Show uncovered line numbers only</summary>

![coverde-value-file-coverage-log-level-line-numbers.png](https://raw.githubusercontent.com/mrverdant13/coverde/main/packages/coverde_cli/doc/examples/terminal/coverde-value-file-coverage-log-level-line-numbers.png)

</details>

<details>
<summary>Show resulting coverage only</summary>

![coverde-value-i-coverage-custom-lcov-info-file-coverage-log-level-none.png](https://raw.githubusercontent.com/mrverdant13/coverde/main/packages/coverde_cli/doc/examples/terminal/coverde-value-i-coverage-custom-lcov-info-file-coverage-log-level-none.png)

</details>
<!-- CLI FEATURES -->

---

# `coverde.yaml` configuration file

The `coverde.yaml` file defines named coverage thresholds for [`coverde check`](#coverde-check), reusable transformation presets for [`coverde transform`](#coverde-transform), and named reports for [`coverde render`](#coverde-render).

The file is optional. These commands read it from the **current working directory**. [`coverde transform`](#coverde-transform) can also load a preset from another file. See [`preset`](#preset).

## File Format

The configuration file uses YAML. Three keys are recognized at the root: `coverage`, `transformations`, and `reports`. Each key can be omitted.

`coverage` is a map of threshold names. `transformations` is a map of presets. Each preset is a named list of transformation steps. `reports` is a map of named reports.

```yaml
# coverde.yaml

coverage:
  pkg-min: 100

transformations:
  preset-name:
    - type: <transformation-type>
      <parameter-1-name>: <value-1>
      <parameter-2-name>: <value-2>
    - type: <transformation-type>
      <parameter-1-name>: <value-1>
```

## Reports

`reports` names the reports that [`coverde render`](#coverde-render) can select. A missing `reports` key means there are no reports.

A `console` report prints one template. It sets `template`. It may set `includeSource` and `destination`. A relative destination resolves from the directory that contains `coverde.yaml`, and an absolute destination is used as given. Omitting `destination` prints the report. The template receives `root`, the coverage tree. `outputPath` on that tree is empty, because a console report does not write a page per node. `directory.files` are the files directly in that directory. Nested files are reached through `directories`. `filesLinesHit`, `filesLinesFound`, and `filesLineRate` (and the same for functions and branches) cover only those direct files. `fileDirectories` lists descendant directories that contain files, sorted by path. A console report, and a `root` or `directory` slot, may set `includeSource`. When it is true, that template's files include source text at every depth. Other templates in the same report keep the instrumented lines only.

A report collapses a single-child directory chain into one node. Set `collapse: false` on a `console` or `files` report to keep a page for each directory, such as `lib`, then `src`, then `entities`. `coverde report` keeps the collapsed tree. A `files` report writes into `destination`. A relative destination is resolved from the directory that contains `coverde.yaml`. The report sets at least one of `root`, `directory`, and `file`. Each slot sets `template` and `path`. `path` is a template for that node. A directory path can read a child `outputPath`, because child paths are assigned first. Page templates also see those paths. A slot may set `variables` and `pages`. Slot `variables` merge into the template `variables` map. Each `pages` entry sets another `path` and optional `variables` that reuse the same template. A `file` slot may set `includeSource`. When it is true, that file page includes source text. `root` and `directory` slots may set it too. `assets` copies static files into the destination after the templates render. Each asset sets `from`, relative to the configuration directory, and `to`, relative to the destination. An asset may set `render: true`. Its source is then a Liquid template with `document`, `variables`, `thresholds`, `columns`, and `color`. The default is a byte copy.

A file template can read function and branch detail, not only the rates. `functionsHit`, `functionsFound`, `branchesHit`, and `branchesFound` are null when the trace never recorded that measurement. A null rate is not 0%. `minus`, `times`, and `round` accept a numeric string, the same way `plus` does, so a `--variable` or a `{% render %}` argument can be used in arithmetic. `round` of an empty value stays empty. `fixed: 2` prints `100.00` and also leaves an empty value empty. `pad` aligns text to a width, and a second argument of `right` aligns it to the right. `truncate` keeps the tail and prefixes `...` when the text is longer. `0` is still empty in `{% if %}` and `default`. Compare `hits == null` and `hits > 0`. `columns` is the terminal width, or 80 when stdout is not a terminal. `color` is true only when the report is printed to a terminal. A destination file stays plain. `colorize` wraps text with `light_red`, `light_green`, `red_bold`, `green_bold`, or `blue_bold`, and returns the text unchanged when `color` is false. `thresholds` is the `coverage` map. `{{ thresholds["pkg-min"] }}` reads one number. `sort_by_rate` sorts files or directories by a rate. A null rate stays after every number. The direction is `asc`, the default, or `desc`. Without the filter, files stay in trace order. `{% capture class %}covValue headerCovTableEntryLo{% endcapture %}` keeps the space between those class names. `{%- -%}` would remove it. `{% render %}` still sees only the arguments it was given. Each file also has `functions` (`name`, `line`, `hits`) and `branches` (`line`, `block`, `branch`, `taken`). `taken` is null when LCOV recorded `-`. Each line has the `branches` that fall on that line, so a line that ran can still show a branch that did not. There is no statement count; a statement column uses the line hit and found counts. The document and each directory expose the same hit and found totals. `document.traceModifiedAt` is the trace file's modification time in ISO-8601, or empty when the caller did not provide one. The trace text itself has no timestamp. `document.testNames` lists distinct `TN:` names in trace order. Each file has `testName`, the first non-empty `TN:` in its record. A later `TN:` on the same path does not replace it. `{{ file.path | report_path }}` is that path relative to the report destination. A relative path stays as it is. A POSIX absolute path uses `absolute`, or `absolute-2` when a file already occupies that name. A drive root uses `drive-c`, a drive-relative path uses `drive-c-relative`, and a UNC path uses `unc-server-share`. These are the same folder names `coverde report` writes. The path jail still rejects an output path that is absolute, empty, trailing-slash, or contains `..`. `file.unrecognized` lists trace lines the parser did not understand. Instrumented `DA:`, `FN:`, and `BRDA:` lines are not in that list. `file.sourceAvailable` is empty when the template did not ask for source, `true` when the source file was read, and `false` when it was requested and the file is missing. A missing file still renders, with instrumented lines and empty source text. A source file that exists but cannot be read still fails the report.

```yaml
reports:
  summary:
    type: console
    template: templates/summary.liquid

  pages:
    type: files
    destination: build/coverage
    root:
      template: templates/root.liquid
      path: index.html
    directory:
      template: templates/directory.liquid
      path: "{{ directory.path | report_path }}/index.html"
    file:
      template: templates/file.liquid
      path: "{{ file.path | report_path }}.html"
      includeSource: true
    assets:
      - from: assets/style.css
        to: style.css
```

### Limits

A template does not get a separate statement count. A statement column uses the line hit and found counts.

`directory.files` are the files directly in that directory. Nested files stay under `directories`.

A files report cannot write the same output path twice.

An output path cannot be absolute, empty, or a trailing slash, and it cannot contain `..`.

`{%- -%}` and `{{- -}}` strip the whitespace around a tag, including a space between class names. `{% render %}` sees only the arguments it was given, not the names of the template that called it.

`0` is empty in `{% if %}` and `default`. Compare `hits == null` and `hits > 0`.

`--report` is required when `coverde.yaml` defines more than one report. One report is used when the flag is omitted.

## Coverage thresholds

`coverage` names the thresholds that [`coverde check`](#coverde-check) can select. A missing `coverage` key means there are no named thresholds.

Each name is a non-empty string that does not parse as a number. Each value is a finite number from 0 to 100 inclusive.

`coverde check` reads `coverde.yaml` from the working directory only when its threshold argument is a name. A numeric argument, such as `coverde check 95`, never opens the file, which is why a numeric name cannot be selected. `coverde check pkg-min` uses the `pkg-min` entry and logs the resolved percentage. An unknown name fails and lists the names defined in that file.

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

Add `file` to load that preset from another `coverde.yaml`. A relative `file` is resolved from the directory of the yaml file that contains the step. An absolute path is used as given.

A `preset` step inside the loaded file still looks up names in that file. A `file` inside it is relative to that file's directory. A cycle across files fails.

```yaml
type: preset
file: <file>  # Example: "../coverde.yaml"
name: <preset-name>  # Example: "ci-workflow"
```

On the command line, a plain string is a preset in the working directory's `coverde.yaml`. A YAML map with `file` loads the preset from that file, relative to the working directory. Quote a path or name that contains `:` or `#`.

```sh
coverde transform --transformations 'preset={file: ../coverde.yaml, name: ci-workflow}'
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

# Monorepo coverage

Run the per-package commands in each package directory. Run the merge and the report once at the repository root.

Named thresholds follow the rules in [Coverage thresholds](#coverage-thresholds).

## Configuration

Commit the shared preset at the repository root. The glob is project-specific.

```yaml
# coverde.yaml

transformations:
  drop-generated-code:
    - type: skip-by-glob
      glob: "**/*.g.dart"
```

Each package keeps its own threshold and points `drop-generated-code` at that root preset. `file` is relative to the package `coverde.yaml`. For a package at `packages/<name>/`, that path is `../../coverde.yaml`. `coverde` reads the yaml in the working directory, so a root-only preset is invisible when the command runs inside a package.

```yaml
# packages/my_package/coverde.yaml

coverage:
  pkg-min: 100

transformations:
  drop-generated-code:
    - type: preset
      file: ../../coverde.yaml
      name: drop-generated-code
```

## Test

In each package directory, gather the tests, then run that file with a package trace. `--coverage-package` attributes the trace to that package.

```sh
$ coverde optimize-tests \
  --include 'test/**_test.dart' \
  --output test/optimized_test.dart
$ dart test \
  --coverage-path coverage/lcov.info \
  --coverage-package <package name> \
  --test-randomize-ordering-seed random \
  test/optimized_test.dart
```

This example uses the Dart test runner. A Flutter package should run `flutter test` in its place.

## Sanitize

In each package that has `coverage/lcov.info`, drop generated files into a new trace. `--mode w` replaces that file. The default mode is append, so a second run would duplicate the trace.

```sh
$ coverde transform \
  --input coverage/lcov.info \
  --output coverage/sanitized.lcov.info \
  --mode w \
  --transformations preset=drop-generated-code
```

## Check

In each package that has the sanitized trace, check it against the `pkg-min` entry in that package's `coverde.yaml`.

```sh
$ coverde check --input coverage/sanitized.lcov.info pkg-min
```

## Merge

Once at the repository root, delete any previous merged trace. `rm` is an alias of [`remove`](#coverde-remove). `--no-dry-run` is required because `remove` previews deletions unless that flag is set.

```sh
$ coverde rm --no-dry-run <root>/coverage/merged.lcov.info
```

Then, in each package that has `coverage/sanitized.lcov.info`, append that trace to the root file. Omit `--mode w` so each package appends. Deleting the root file first drops packages that no longer have a trace. `relative` rewrites paths from the repository root, so `lib/` paths from different packages do not collide.

```sh
$ coverde transform \
  --input coverage/sanitized.lcov.info \
  --output <root>/coverage/merged.lcov.info \
  --transformations relative=<root>
```

## Report

Once at the repository root, generate the HTML report from the merged trace.

```sh
$ coverde report \
  --input <root>/coverage/merged.lcov.info \
  --output <root>/coverage/html/
```

<details>
<summary>Melos</summary>

The same steps as [Melos][melos_link] scripts. Per-package scripts use `exec`, because Melos applies `packageFilters` to `exec` scripts. `dirExists: test` selects every package that has a `test/` directory.

```yaml
# scripts in melos.yaml (older Melos), or melos.scripts in the root pubspec.yaml

scripts:
  test:
    description: Run tests and generate a coverage trace for a package
    exec: >
      coverde optimize-tests
      --include 'test/**_test.dart'
      --output test/optimized_test.dart
      &&
      dart test
      --coverage-path coverage/lcov.info
      --coverage-package "$MELOS_PACKAGE_NAME"
      --test-randomize-ordering-seed random
      test/optimized_test.dart
    packageFilters:
      dirExists:
        - test

  coverage.sanitize:
    description: Remove generated files from a package coverage trace
    exec: >
      coverde transform
      --input coverage/lcov.info
      --output coverage/sanitized.lcov.info
      --mode w
      --transformations preset=drop-generated-code
    packageFilters:
      fileExists:
        - coverage/lcov.info

  coverage.check:
    description: Check a package coverage trace against its pkg-min threshold
    exec: >
      coverde check
      --input coverage/sanitized.lcov.info
      pkg-min
    packageFilters:
      fileExists:
        - coverage/sanitized.lcov.info

  coverage.merge:
    description: Merge sanitized package coverage traces into one root trace
    run: >
      coverde rm
      --no-dry-run
      "$MELOS_ROOT_PATH/coverage/merged.lcov.info"
      &&
      melos exec
      --file-exists coverage/sanitized.lcov.info
      --
      coverde transform
      --input coverage/sanitized.lcov.info
      --output "$MELOS_ROOT_PATH/coverage/merged.lcov.info"
      --transformations relative="$MELOS_ROOT_PATH"

  coverage.report:
    description: Generate an HTML coverage report
    run: >
      coverde report
      --input "$MELOS_ROOT_PATH/coverage/merged.lcov.info"
      --output "$MELOS_ROOT_PATH/coverage/html/"
```

</details>

---

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
[dart_cli_distribution_link]: https://dart.dev/tools/cli-distribution
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[melos_link]: https://melos.invertase.dev/
[open_issue_link]: https://github.com/mrverdant13/coverde/issues/new
[pub_badge]: https://img.shields.io/pub/v/coverde.svg
[pub_link]: https://pub.dev/packages/coverde
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://github.com/VeryGoodOpenSource/very_good_analysis
