import 'dart:convert';

import 'package:coverde/src/entities/coverage_document.dart';
import 'package:coverde/src/utils/coverage_tree.dart';
import 'package:test/test.dart';

void main() {
  test('formatCoverageTree prints nested directories and files', () {
    const trace = '''
SF:test/dir_1/a.dart
DA:1,1
end_of_record
SF:test/dir_1/b.dart
DA:1,0
end_of_record
SF:test/dir_2/c.dart
DA:1,1
end_of_record
SF:test/dir_2/deep/d.dart
DA:1,1
end_of_record
''';
    const expected = '''
Node: test (75.00% - 3/4)
├─ Node: test/dir_1 (50.00% - 1/2)
│  ├─ SF: test/dir_1/a.dart (100.00% - 1/1)
│  ├─ SF: test/dir_1/b.dart (0.00% - 0/1)
│
├─ Node: test/dir_2 (100.00% - 2/2)
│  ├─ Node: test/dir_2/deep (100.00% - 1/1)
│  │  ├─ SF: test/dir_2/deep/d.dart (100.00% - 1/1)
│  │
│  ├─ SF: test/dir_2/c.dart (100.00% - 1/1)
│
''';

    final result = formatCoverageTree(CoverageDocument.parse(trace).tree);

    const splitter = LineSplitter();
    expect(
      splitter.convert(result).map((line) => line.trim()),
      splitter.convert(expected).map((line) => line.trim()),
    );
  });

  test('formatCoverageTree prints n/a when a file has no lines', () {
    const trace = '''
SF:lib/a.dart
FN:1,main
FNDA:1,main
end_of_record
''';

    final result = formatCoverageTree(CoverageDocument.parse(trace).tree);

    expect(result, contains('Node: lib (n/a - 0/0)'));
    expect(result, contains('SF: lib/a.dart (n/a - 0/0)'));
  });
}
