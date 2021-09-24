# Coverage Utils

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

A set of commands for coverage info files manipulation.

---

# Installing

```sh
$ dart pub global activate --source git https://github.com/mrverdant13/cov_utils.git
```

---

# Commands

## `$ x`

Generic actions.

```
A set of commands for generic functionalities.

Usage: x <command> [arguments]

Global options:
-h, --help    Print this usage information.

Available commands:
  remove   Remove a set of files and folders.

Run "x help <command>" for more information about a command.
```

### `x` sub-commands

<details><summary><code>x rm</code></summary>
<p>

```
Remove a set of files and folders.

Usage: x remove [arguments]
-h, --help                   Print this usage information.
    --[no-]accept-absence    Accept absence of a file or folder.
                             When an element is not present:
                             - If enabled, the command will continue.
                             - If disabled, the command will fail.
                             (defaults to on)

Run "x help" to see global options.
```

</p>
</details>

---

## `$ cov`

Coverage info actions.

```
A set of commands that encapsulate coverage-related functionalities.

Usage: cov <command> [arguments]

Global options:
-h, --help    Print this usage information.

Available commands:
  filter   Filter a coverage info file.
  value    Compute the coverage value (%) of an info file.

Run "cov help <command>" for more information about a command.
```

### `cov` sub-commands

<details><summary><code>cov filter</code></summary>
<p>

```
Filter a coverage info file.

Filter the coverage info by ignoring data related to files with paths that matches the given PATTERNS.
The coverage data is taken from the ORIGIN_LCOV_FILE file and the result is appended to the DESTINATION_LCOV_FILE file.

Usage: cov filter [arguments]
-h, --help                                   Print this usage information.
-i, --ignore-patterns=<PATTERNS>             Set of comma-separated path patterns of the files to be ignored.
                                             Consider that the coverage info of each file is checked as a multiline block.
                                             Each bloc starts with `SF:` and ends with `end_of_record`.
-o, --origin=<ORIGIN_LCOV_FILE>              Origin coverage info file to pick coverage data from.
                                             (defaults to "coverage/lcov.info")
-d, --destination=<DESTINATION_LCOV_FILE>    Destination coverage info file to dump the resulting coverage data into.
                                             (defaults to "coverage/wiped.lcov.info")

Run "cov help" to see global options.
```

</p>
</details>

<details><summary><code>cov value</code></summary>
<p>

```
Compute the coverage value (%) of an info file.

Compute the coverage value of the LCOV_FILE info file.

Usage: cov value [arguments]
-h, --help                Print this usage information.
-f, --file=<LCOV_FILE>    Coverage info file to be used for the coverage value computation.
                          (defaults to "coverage/lcov.info")
-p, --[no-]print-files    Print coverage value for each source file listed in the LCOV_FILE info file.
                          (defaults to on)

Run "cov help" to see global options.
```

</p>
</details>

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
