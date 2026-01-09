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
