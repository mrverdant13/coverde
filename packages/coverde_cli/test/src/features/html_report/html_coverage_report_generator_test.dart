import 'dart:async';
import 'dart:convert';

import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/features/html_report/html_coverage_report_generator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('HtmlCoverageReportGenerator', () {
    late Directory reportDir;

    setUp(() {
      reportDir = Directory.systemTemp.createTempSync('coverde_html_');
    });

    tearDown(() {
      if (reportDir.existsSync()) reportDir.deleteSync(recursive: true);
    });

    test('places a POSIX-absolute path under absolute', () {
      _generate(
        reportDir: reportDir,
        sources: const {
          '/lib/a.dart': 'void absolute() {}',
          'lib/b.dart': 'void relative() {}',
        },
      );

      expect(
        File(
          p.join(reportDir.path, 'absolute', 'lib', 'a.dart.html'),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(reportDir.path, 'lib', 'b.dart.html')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(reportDir.path, 'index.html')).readAsStringSync(),
        contains('href="absolute/index.html"'),
      );
    });

    test('nests an absolute directory under absolute', () {
      _generate(
        reportDir: reportDir,
        sources: const {'/lib/a.dart': 'void absolute() {}'},
        tree:
            (files) => CovDir(
              source: Directory(''),
              elements: [CovDir(source: Directory('/lib'), elements: files)],
            ),
      );

      expect(
        File(
          p.join(reportDir.path, 'absolute', 'lib', 'a.dart.html'),
        ).existsSync(),
        isTrue,
      );
    });

    test('places a drive-qualified path under drive-c', () {
      _generate(
        reportDir: reportDir,
        sources: const {
          'C:/src/a.dart': 'void drive() {}',
          'lib/b.dart': 'void relative() {}',
        },
      );

      expect(
        File(
          p.join(reportDir.path, 'drive-c', 'src', 'a.dart.html'),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(reportDir.path, 'lib', 'b.dart.html')).existsSync(),
        isTrue,
      );
    });

    test('keeps a shared drive root without a drive folder', () {
      _generate(
        reportDir: reportDir,
        sources: const {
          'C:/proj/lib/a.dart': 'void library() {}',
          'C:/proj/bin/main.dart': 'void main() {}',
        },
      );

      expect(
        File(p.join(reportDir.path, 'lib', 'a.dart.html')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(reportDir.path, 'bin', 'main.dart.html')).existsSync(),
        isTrue,
      );
      expect(File(p.join(reportDir.path, 'drive-c')).existsSync(), isFalse);
    });

    test('places each drive letter in its own folder', () {
      _generate(
        reportDir: reportDir,
        sources: const {
          'C:/a.dart': 'void windows() {}',
          'D:/b.dart': 'void other() {}',
        },
      );

      expect(
        File(p.join(reportDir.path, 'drive-c', 'a.dart.html')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(reportDir.path, 'drive-d', 'b.dart.html')).existsSync(),
        isTrue,
      );
    });

    test('uses absolute-2 when absolute is a source path', () {
      _generate(
        reportDir: reportDir,
        sources: const {
          'absolute/a.dart': 'void named() {}',
          '/b.dart': 'void root() {}',
        },
      );

      expect(
        File(p.join(reportDir.path, 'absolute', 'a.dart.html')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(reportDir.path, 'absolute-2', 'b.dart.html')).existsSync(),
        isTrue,
      );
    });

    test('skips folder names that are already taken', () {
      _generate(
        reportDir: reportDir,
        sources: const {
          'absolute/a.dart': 'void first() {}',
          'absolute-2/c.dart': 'void second() {}',
          '/b.dart': 'void root() {}',
        },
      );

      expect(
        File(p.join(reportDir.path, 'absolute-3', 'b.dart.html')).existsSync(),
        isTrue,
      );
    });

    test('rejects a path that leaves the report directory', () {
      final failure = _failure(
        reportDir: reportDir,
        sources: const {
          '../shared/b.dart': 'void shared() {}',
          'lib/a.dart': 'void library() {}',
        },
      );

      expect(
        failure,
        isA<GenerateHtmlCoverageReportOutsideDirectoryFailure>().having(
          (failure) => failure.readableMessage,
          'readableMessage',
          contains('would be written outside the report directory'),
        ),
      );
    });
  });
}

void _generate({
  required Directory reportDir,
  required Map<String, String> sources,
  CovDir Function(List<CovFile> files)? tree,
}) {
  final failure = _failure(reportDir: reportDir, sources: sources, tree: tree);
  if (failure != null) throw failure;
}

GenerateHtmlCoverageReportFailure? _failure({
  required Directory reportDir,
  required Map<String, String> sources,
  CovDir Function(List<CovFile> files)? tree,
}) {
  final outer = Zone.current;
  try {
    IOOverrides.runZoned(
      () {
        final files = [
          for (final entry in sources.entries)
            CovFile.parse('SF:${entry.key}\nDA:1,1'),
        ];
        const HtmlCoverageReportGenerator().generate(
          root: tree?.call(files) ?? CovDir.tree(covFiles: files),
          traceFileName: 'lcov.info',
          parentReportDirAbsPath: reportDir.path,
          traceFileModificationDate: DateTime.utc(2024),
          medium: 80,
          high: 90,
        );
      },
      createFile: (filePath) {
        final source = sources[filePath];
        if (source != null) return _SourceFile(filePath, source);
        return outer.run(() => File(filePath));
      },
    );
  } on GenerateHtmlCoverageReportFailure catch (failure) {
    return failure;
  }
  return null;
}

final class _SourceFile extends Fake implements File {
  _SourceFile(this.filePath, this._source);

  final String filePath;
  final String _source;

  @override
  String get path => filePath;

  @override
  List<String> readAsLinesSync({Encoding encoding = utf8}) => [_source];

  @override
  Directory get parent => Directory(p.posix.dirname(filePath));
}
