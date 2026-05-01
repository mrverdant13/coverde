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
