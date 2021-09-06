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

## `$ cov`

Coverage info actions.

```
A set of commands that encapsulate coverage-related functionalities.

Usage: cov <command> [arguments]

Global options:
-h, --help    Print this usage information.

Available commands:
  filter   Filter a coverage info file.

Run "cov help <command>" for more information about a command.
```

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
