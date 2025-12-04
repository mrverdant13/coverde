## Unreleased

- **BREAKING FEAT**: use `base-directory` option instead of `paths-parent` option in `filter` command (#158).
- **BREAKING FEAT**: add `--dry-run` flag to `remove` command to preview deletions without actually deleting (#214).
- **FIX**: use platform-dependent path handling (#82).
- **FIX**: validate regex patterns in `filter` command (#212).
- **FIX**: validate threshold values in `report` command (#212).
- **FIX**: proper file deletions (#221).
- **FIX**: validate log level values in `check` and `value` commands (#222).
- **FIX**: safer update checks (#226).
- **FEAT**: use Dart 3.5.0 as minimum SDK version (#114).
- **FEAT**: add `optimize-tests` command (#115).
- **FEAT**: add `file-coverage-log-level` option to `check` and `value` commands (#118).
- **FEAT**: add file locking to `filter` command to prevent race conditions when multiple processes write to the same output file (#211).
- **PERF**: use streaming parser for trace files (#217).
- **REFACTOR**: use `mason_logger` package for logging (#216).
- **REFACTOR**: deterministic OS detection (#219, #223).

## 0.2.0+2

- **FEAT**: optional prefix for filtered paths (#69).
- **DOCS**: update README (#70).
- **DOCS**: add topics and screenshots to Pub docs (#71).

## 0.2.0+1

- **FIX**: use proper version for update check (#67).

## 0.2.0

- **FEAT**: require Dart 3 (#52).
- **REFACTOR**: solve typos (#63).
- **FIX**: keep relative paths when filtering (#60).
- **DOCS**: use representative usage examples (#61).
- **DOCS**: update links and references (#58).

## 0.1.0+1

- **FIX**: use proper version for update check.
- **DOCS**: set README images URLs.

## 0.1.0

- **FEAT**: create `check` command.
- **FEAT**: create `filter` command.
- **FEAT**: create `remove` command.
- **FEAT**: create `report` command.
- **FEAT**: create `value` command.
- **TEST**: ensure 100% test coverage.
