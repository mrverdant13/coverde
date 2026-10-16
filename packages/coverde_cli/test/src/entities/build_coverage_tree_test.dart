import 'package:coverde/src/entities/build_coverage_tree.dart';
import 'package:coverde/src/entities/coverage_file.dart';
import 'package:coverde/src/entities/coverage_line.dart';
import 'package:coverde/src/entities/coverage_trace_entry.dart';
import 'package:test/test.dart';

void main() {
  CoverageFile sourceFile(String path) {
    return CoverageFile(
      path: path,
      entries: const [CoverageSourceEntry()],
      lines: const [CoverageLine(number: 1, hits: 1)],
      functions: null,
      branches: null,
    );
  }

  group('buildCoverageTree', () {
    test('returns an empty root when there are no files', () {
      final tree = buildCoverageTree(const <CoverageFile>[]);

      expect(tree.path, isEmpty);
      expect(tree.directories, isEmpty);
      expect(tree.files, isEmpty);
    });

    test('places a file with no directory on the empty root', () {
      final tree = buildCoverageTree([sourceFile('a.dart')]);

      expect(tree.path, isEmpty);
      expect(tree.directories, isEmpty);
      expect(tree.files.single.path, 'a.dart');
    });

    test('collapses a single-child directory chain', () {
      final tree = buildCoverageTree([sourceFile('lib/src/deep/a.dart')]);

      expect(tree.path, 'lib/src/deep');
      expect(tree.directories, isEmpty);
      expect(tree.files.single.path, 'lib/src/deep/a.dart');
    });

    test('keeps files that share a parent on one node, in trace order', () {
      final tree = buildCoverageTree([
        sourceFile('lib/b.dart'),
        sourceFile('lib/a.dart'),
      ]);

      expect(tree.path, 'lib');
      expect(tree.directories, isEmpty);
      expect(tree.files.map((file) => file.path), ['lib/b.dart', 'lib/a.dart']);
    });

    test('uses an empty root when files do not share a parent', () {
      final tree = buildCoverageTree([
        sourceFile('dir_2/a.dart'),
        sourceFile('dir_1/b.dart'),
      ]);

      expect(tree.path, isEmpty);
      expect(tree.files, isEmpty);
      expect(tree.directories.map((directory) => directory.path), [
        'dir_2',
        'dir_1',
      ]);
    });

    test(
      'keeps a file beside the child directory that continues its prefix',
      () {
        final tree = buildCoverageTree([
          sourceFile('lib/a.dart'),
          sourceFile('lib/src/b.dart'),
        ]);

        expect(tree.path, 'lib');
        expect(tree.files.single.path, 'lib/a.dart');
        expect(tree.directories.single.path, 'lib/src');
        expect(tree.directories.single.files.single.path, 'lib/src/b.dart');
      },
    );

    test(
      'keeps a relative file and an absolute file in separate directories',
      () {
        final tree = buildCoverageTree([
          sourceFile('local.dart'),
          sourceFile('/external.dart'),
        ]);

        expect(tree.path, isEmpty);
        expect(tree.files.single.path, 'local.dart');
        expect(tree.directories.single.path, '/');
        expect(tree.directories.single.files.single.path, '/external.dart');
      },
    );

    test('places a file at the filesystem root on that root', () {
      final tree = buildCoverageTree([sourceFile('/b.dart')]);

      expect(tree.path, '/');
      expect(tree.files.single.path, '/b.dart');
      expect(tree.directories, isEmpty);
    });
  });
}
