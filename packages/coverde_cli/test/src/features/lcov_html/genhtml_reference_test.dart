// cspell:ignore genhtml gcov
//
// Reference produced by LCOV genhtml 2.0-1 from [trace.lcov.info].
// Source paths in that trace were rewritten to absolute paths under the
// directory that contains lib/a.dart and lib/src/b.dart, then stripped with
// --prefix set to that directory:
//
// genhtml --branch-coverage --function-coverage --title render-e2e
//   --current-date '2026-11-25 00:00:00' --prefix <source-root>
//   --rc genhtml_med_limit=75 --rc genhtml_hi_limit=90
//   -o <output> <absolute-trace>
//
// The limits are the coverde report defaults. genhtml is not a runtime
// dependency.

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  final fixtureDirectory = p.join(
    Directory.current.path,
    'test',
    'src',
    'features',
    'lcov_html',
    'fixtures',
    'genhtml',
  );

  test('genhtml reference contains the built-in HTML pages', () {
    final actual = _relativeFiles(fixtureDirectory);
    expect(actual, _referencePages);
  });
}

Set<String> _relativeFiles(String root) {
  return Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => p.relative(file.path, from: root).replaceAll(r'\', '/'))
      .toSet();
}

const _referencePages = {
  'trace.lcov.info',
  'index.html',
  'index-sort-l.html',
  'index-sort-f.html',
  'index-sort-b.html',
  'gcov.css',
  'amber.png',
  'emerald.png',
  'glass.png',
  'ruby.png',
  'snow.png',
  'updown.png',
  'lib/index.html',
  'lib/index-sort-l.html',
  'lib/index-sort-f.html',
  'lib/index-sort-b.html',
  'lib/a.dart.gcov.html',
  'lib/a.dart.func.html',
  'lib/a.dart.func-c.html',
  'lib/src/index.html',
  'lib/src/index-sort-l.html',
  'lib/src/index-sort-f.html',
  'lib/src/index-sort-b.html',
  'lib/src/b.dart.gcov.html',
  'lib/src/b.dart.func.html',
  'lib/src/b.dart.func-c.html',
};
