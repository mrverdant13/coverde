# Coverage Utils

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

A set of commands for coverage info files manipulation.

---

# Installing

```sh
$ dart pub global activate --source git https://github.com/mrverdant13/coverde.git
```

---

# Commands

## `$ coverde`

Coverage info actions.

```
A set of commands that encapsulate coverage-related functionalities.

Usage: coverde <command> [arguments]

Global options:
-h, --help    Print this usage information.

Available commands:
  filter   Filter a coverage info file.
  remove   Remove a set of files and folders.
  report   Generate the coverage report from a tracefile.
  value    Compute the coverage value (%) of an info file.

Run "coverde help <command>" for more information about a command.
```

### `coverde` sub-commands

<details><summary><code>coverde filter</code></summary>
<p>

```
Filter a coverage info file.

Filter the coverage info by ignoring data related to files with paths that matches the given PATTERNS.
The coverage data is taken from the ORIGIN_LCOV_FILE file and the result is appended to the DESTINATION_LCOV_FILE file.

Usage: coverde filter [arguments]
-h, --help                                   Print this usage information.
-i, --ignore-patterns=<PATTERNS>             Set of comma-separated path patterns of the files to be ignored.
                                             Consider that the coverage info of each file is checked as a multiline block.
                                             Each bloc starts with `SF:` and ends with `end_of_record`.
-o, --origin=<ORIGIN_LCOV_FILE>              Origin coverage info file to pick coverage data from.
                                             (defaults to "coverage/lcov.info")
-d, --destination=<DESTINATION_LCOV_FILE>    Destination coverage info file to dump the resulting coverage data into.
                                             (defaults to "coverage/wiped.lcov.info")

Run "coverde help" to see global options.
```

</p>
</details>

<details><summary><code>coverde remove</code></summary>
<p>

```
Remove a set of files and folders.

Usage: coverde remove [arguments]
-h, --help                   Print this usage information.
    --[no-]accept-absence    Accept absence of a file or folder.
                             When an element is not present:
                             - If enabled, the command will continue.
                             - If disabled, the command will fail.
                             (defaults to on)

Run "coverde help" to see global options.
```

</p>
</details>

<details><summary><code>coverde report</code></summary>
<p>

```
Generate the coverage report from a tracefile.

Genrate the coverage report inside REPORT_DIR from the TRACEFILE tracefile.

Usage: coverde report [arguments]
-h, --help                              Print this usage information.
-i, --input-tracefile=<TRACEFILE>       Coverage tracefile to be used for the coverage report generation.
                                        (defaults to "coverage/lcov.info")
-o, --output-report-dir=<REPORT_DIR>    Destination directory where the generated coverage report will be stored.
                                        (defaults to "coverage/html/")

Threshold values (%):
These options provide reference coverage values for the HTML report styling.

High: HIGH_VAL <= coverage <= 100
Medium: MEDIUM_VAL <= coverge < HIGH_VAL
Low: 0 <= coverage < MEDIUM_VAL

    --medium=<MEDIUM_VAL>               Medium threshold.
                                        (defaults to "75")
    --high=<HIGH_VAL>                   High threshold.
                                        (defaults to "90")

Run "coverde help" to see global options.
```

</p>
</details>

<details><summary><code>coverde value</code></summary>
<p>

```
Compute the coverage value (%) of an info file.

Compute the coverage value of the LCOV_FILE info file.

Usage: coverde value [arguments]
-h, --help                Print this usage information.
-f, --file=<LCOV_FILE>    Coverage info file to be used for the coverage value computation.
                          (defaults to "coverage/lcov.info")
-p, --[no-]print-files    Print coverage value for each source file listed in the LCOV_FILE info file.
                          (defaults to on)

Run "coverde help" to see global options.
```

</p>
</details>

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
