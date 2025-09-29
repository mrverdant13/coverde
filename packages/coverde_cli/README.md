# Coverde

[![pub package][pub_badge]][pub_link]
[![License: MIT][license_badge]][license_link]
[![Dart CI][dart_ci_badge]][dart_ci_link]
[![codecov][codecov_badge]][codecov_link]
[![CodeFactor][codefactor_badge]][codefactor_link]
[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![melos][melos_badge]][melos_link]

A CLI for basic coverage trace files manipulation.

---

# Index

- [Installing](#installing)
- [Features](#features)
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
- [**Generate the coverage report from a trace file.**](#coverde-report)
- [**Remove a set of files and folders.**](#coverde-remove)
- [**Compute the coverage value (%) of an info file.**](#coverde-value)

## `coverde optimize-tests`

Optimize tests by gathering them.

### Options

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


## `coverde check`

Check the coverage value (%) computed from a trace file.

The unique argument should be an integer between 0 and 100.\
This parameter indicates the minimum value for the coverage to be accepted.

### Options

#### Single-options

- `--input`

  Trace file used for the coverage check.\
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

![coverde check 50](https://github.com/mrverdant13/coverde/blob/main/packages/coverde_cli/doc/gen/coverde-check-50.png)
![coverde check --file-coverage-log-level line-numbers 100](https://github.com/mrverdant13/coverde/blob/main/packages/coverde_cli/doc/gen/coverde-check-file-coverage-log-level-line-numbers-100.png)
![coverde check -i coverage/custom.lcov.info --file-coverage-log-level none 75](https://github.com/mrverdant13/coverde/blob/main/packages/coverde_cli/doc/gen/coverde-check-i-coverage-custom-lcov-info-file-coverage-log-level-none-75.png)


## `coverde filter`

Filter a coverage trace file.

Filter the coverage info by ignoring data related to files with paths that matches the given FILTERS.\
The coverage data is taken from the INPUT_LCOV_FILE file and the result is appended to the OUTPUT_LCOV_FILE file.

All the relative paths in the resulting coverage trace file will be prefixed with PATHS_PARENT, if provided.\
If an absolute path is found in the coverage trace file, the process will fail.

### Options

#### Single-options

- `--input`

  Origin coverage info file to pick coverage data from.\
  **Default value:** `coverage/lcov.info`

- `--output`

  Destination coverage info file to dump the resulting coverage data into.\
  **Default value:** `coverage/filtered.lcov.info`

- `--paths-parent`

  Path to be used to prefix all the paths in the resulting coverage trace file.

- `--mode`

  The mode in which the OUTPUT_LCOV_FILE can be generated.\
  **Default value:** `a`\
  **Allowed values:**
    - `a`: Append filtered content to the OUTPUT_LCOV_FILE content, if any.
    - `w`: Override the OUTPUT_LCOV_FILE content, if any, with the filtered content.

#### Multi-options

- `--filters`

  Set of comma-separated path patterns of the files to be ignored.\
  **Default value:** _None_


## `coverde report`

Generate the coverage report from a trace file.

Generate the coverage report inside REPORT_DIR from the TRACE_FILE trace file.

### Options

#### Single-options

- `--input`

  Coverage trace file to be used for the coverage report generation.\
  **Default value:** `coverage/lcov.info`

- `--output`

  Destination directory where the generated coverage report will be stored.\
  **Default value:** `coverage/html/`

- `--medium`

  Medium threshold.\
  **Default value:** `75`

- `--high`

  High threshold.\
  **Default value:** `90`

#### Flags

- `--launch`

  Launch the generated report in the default browser.
  (defaults to off)\
  **Default value:** _Disabled_


## `coverde remove`

Remove a set of files and folders.

### Options

#### Flags

- `--accept-absence`

  Accept absence of a file or folder.
  When an element is not present:
  - If enabled, the command will continue.
  - If disabled, the command will fail.\
  **Default value:** _Enabled_


## `coverde value`

Compute the coverage value (%) of an info file.

Compute the coverage value of the LCOV_FILE info file.

### Options

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

![coverde value --file-coverage-log-level line-numbers](https://github.com/mrverdant13/coverde/blob/main/packages/coverde_cli/doc/gen/coverde-value-file-coverage-log-level-line-numbers.png)
![coverde value -i coverage/custom.lcov.info --file-coverage-log-level none](https://github.com/mrverdant13/coverde/blob/main/packages/coverde_cli/doc/gen/coverde-value-i-coverage-custom-lcov-info-file-coverage-log-level-none.png)
![coverde value](https://github.com/mrverdant13/coverde/blob/main/packages/coverde_cli/doc/gen/coverde-value.png)
<!-- CLI FEATURES -->

---

# Usage with [melos][melos_link]

If your project uses melos to manage its multi-package structure, it could be handy to collect test coverage data in a unified trace file.

This can be achieved by defining a melos script as follows:

```yaml
merge-trace-files:
  description: Merge all packages coverage trace files ignoring data related to generated files.
  run: >
    coverde rm MELOS_ROOT_PATH/coverage/filtered.lcov.info &&
    melos exec --file-exists=coverage/lcov.info -- "coverde filter --input ./coverage/lcov.info --output MELOS_ROOT_PATH/coverage/filtered.lcov.info --paths-parent MELOS_PACKAGE_PATH --filters '\.g\.dart'"
```

`merge-trace-files` is the melos script that merges the coverage trace file of all tested packages contained within the project

First, the script removes the `filtered.lcov.info` file, if it exists, from the `coverage` folder in the root folder of the project.

Then, the script executes the `coverde filter` command for each package that contains a `coverage/lcov.info` file, using its content as input and the `filtered.lcov.info` file in the project root as output.

The resulting merged trace file ignores data related to generated files, which are identified by the `.g.dart` extension.

Each referenced file path is prefixed with the package path, so that the resulting merged trace file contains a set of paths that represent the actual project structure, which is critical for the `coverde report` command to work properly, as it relies on the file system to generate the HTML report.

---

# CI integration for coverage checks

If your project uses GitHub Actions for CI, you might already know [very_good_coverage][very_good_coverage_link], which offers a simple but effective method for coverage validation.

However, adding coverage checks to CI workflows hosted by other alternatives is not always that straightforward.

To solve this, after enabling Dart or Flutter in your CI workflow, according to your project requirements, you can use `coverde` and its `check` tool by adding the following commands to your workflow steps:

- `dart pub global activate coverde`
- `coverde check <min_coverage>`

# Bugs or Requests

If you encounter any problems or you believe the CLI is missing a feature, feel free to [open an issue on GitHub][open_issue_link].

Pull request are also welcome. See [CONTRIBUTING.md][_docs_contributing_link].

[_docs_contributing_link]: https://github.com/mrverdant13/coverde/blob/main/CONTRIBUTING.md
[_docs_coverde_check_example_1]: https://github.com/mrverdant13/coverde/blob/main/packages/coverde_cli/doc/check_result_pass.png?raw=true
[_docs_coverde_check_example_2]: https://github.com/mrverdant13/coverde/blob/main/packages/coverde_cli/doc/check_result_fail.png?raw=true
[_docs_coverde_report_example_1]: https://github.com/mrverdant13/coverde/blob/main/packages/coverde_cli/doc/report_directory_example.png?raw=true
[_docs_coverde_report_example_2]: https://github.com/mrverdant13/coverde/blob/main/packages/coverde_cli/doc/report_file_example.png?raw=true
[codecov_badge]: https://codecov.io/gh/mrverdant13/coverde/branch/main/graph/badge.svg
[codecov_link]: https://codecov.io/gh/mrverdant13/coverde
[codefactor_badge]: https://www.codefactor.io/repository/github/mrverdant13/coverde/badge
[codefactor_link]: https://www.codefactor.io/repository/github/mrverdant13/coverde
[dart_ci_badge]: https://github.com/mrverdant13/coverde/workflows/Dart%20CI/badge.svg
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
