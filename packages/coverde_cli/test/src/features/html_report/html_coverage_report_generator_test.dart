import 'dart:async';
import 'dart:convert';

import 'package:coverde/src/entities/build_coverage_tree.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/features/html_report/html_coverage_report_generator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  const generator = HtmlCoverageReportGenerator();
  final modifiedAt = DateTime.utc(2026, 10, 16, 12);

  CoverageFile sourceFile({
    required String path,
    List<CoverageLine> lines = const [],
  }) {
    return CoverageFile(
      path: path,
      entries: const [CoverageSourceEntry()],
      lines: lines,
      functions: null,
      branches: null,
    );
  }

  void generate(CoverageDirectory root, Directory reportDir) {
    generator.generate(
      root: root,
      traceFileName: 'lcov.info',
      parentReportDirAbsPath: reportDir.path,
      traceFileModificationDate: modifiedAt,
      medium: 75,
      high: 90,
    );
  }

  group('$HtmlCoverageReportGenerator', () {
    test('writes low, medium, high, and missing line rates', () {
      final directory = Directory.systemTemp.createTempSync('coverde-html-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final sources = {
        'empty.dart': 'void empty() {}\n',
        'miss.dart': 'void miss() {}\n',
        'partial.dart': 'void partial() {\n  return;\n}\n',
        'hit.dart': 'void hit() {}\n',
      };
      for (final MapEntry(key: name, value: source) in sources.entries) {
        File(p.join(directory.path, name)).writeAsStringSync(source);
      }
      final previous = Directory.current;
      Directory.current = directory;
      addTearDown(() => Directory.current = previous);
      final reportDir = Directory(p.join(directory.path, 'html'));
      final root = CoverageDirectory(
        path: '',
        directories: const [],
        files: [
          sourceFile(path: 'empty.dart'),
          sourceFile(
            path: 'miss.dart',
            lines: const [CoverageLine(number: 1, hits: 0)],
          ),
          sourceFile(
            path: 'partial.dart',
            lines: const [
              CoverageLine(number: 1, hits: 3),
              CoverageLine(number: 2, hits: 0),
              CoverageLine(number: 3, hits: 1),
              CoverageLine(number: 4, hits: 1),
            ],
          ),
          sourceFile(
            path: 'hit.dart',
            lines: const [CoverageLine(number: 1, hits: 1)],
          ),
        ],
      );

      generate(root, reportDir);

      final index =
          File(p.join(reportDir.path, 'index.html')).readAsStringSync();
      expect(index, contains('n/a'));
      expect(index, contains('0.00'));
      expect(index, contains('headerCovTableEntryLo'));
      expect(index, contains('75.00'));
      expect(index, contains('coverPerMed'));
      expect(index, contains('100.00'));
      expect(index, contains('coverPerHi'));
      expect(index, contains('href="miss.dart.html"'));
      expect(
        File(p.join(reportDir.path, 'report_style.css')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(reportDir.path, 'sort_alpha.png')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(reportDir.path, 'sort_numeric.png')).existsSync(),
        isTrue,
      );

      final partial =
          File(p.join(reportDir.path, 'partial.dart.html')).readAsStringSync();
      expect(partial, contains('class="sourceLine lineCov"'));
      expect(partial, contains('class="sourceLine lineNoCov"'));
      expect(partial, contains('void partial() {'));
      expect(partial, contains('href="./index.html"'));
    });

    test('links a nested file back to the report root', () {
      final directory = Directory.systemTemp.createTempSync('coverde-html-');
      addTearDown(() => directory.deleteSync(recursive: true));
      File(p.join(directory.path, 'lib', 'src', 'a.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('void nested() {}\n');
      File(p.join(directory.path, 'bin', 'b.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('void other() {}\n');
      final previous = Directory.current;
      Directory.current = directory;
      addTearDown(() => Directory.current = previous);
      final reportDir = Directory(p.join(directory.path, 'html'));
      final root = buildCoverageTree([
        sourceFile(
          path: 'lib/src/a.dart',
          lines: const [CoverageLine(number: 1, hits: 1)],
        ),
        sourceFile(
          path: 'bin/b.dart',
          lines: const [CoverageLine(number: 1, hits: 0)],
        ),
      ]);

      generate(root, reportDir);

      final page =
          File(
            p.join(reportDir.path, 'lib', 'src', 'a.dart.html'),
          ).readAsStringSync();
      expect(page, contains('href="../../report_style.css"'));
      expect(page, contains('void nested() {}'));
      expect(
        File(
          p.join(reportDir.path, 'lib', 'src', 'index.html'),
        ).readAsStringSync(),
        contains('href="a.dart.html"'),
      );
    });

    test('keeps absolute and relative sources in separate report paths', () {
      final directory = Directory.systemTemp.createTempSync('coverde-html-');
      addTearDown(() => directory.deleteSync(recursive: true));
      File(p.join(directory.path, 'lib', 'b.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('void relative() {}\n');
      final previous = Directory.current;
      Directory.current = directory;
      addTearDown(() => Directory.current = previous);
      final reportDir = Directory(p.join(directory.path, 'html'));
      final root = buildCoverageTree([
        sourceFile(
          path: '/lib/a.dart',
          lines: const [CoverageLine(number: 1, hits: 1)],
        ),
        sourceFile(
          path: 'lib/b.dart',
          lines: const [CoverageLine(number: 1, hits: 0)],
        ),
      ]);
      final outer = Zone.current;

      IOOverrides.runZoned(
        () => generate(root, reportDir),
        createFile: (filePath) {
          if (filePath == '/lib/a.dart') {
            return _SourceFile(filePath, const ['void absolute() {}']);
          }
          return outer.run(() => File(filePath));
        },
      );

      final index =
          File(p.join(reportDir.path, 'index.html')).readAsStringSync();
      expect(index, contains('href="absolute/lib/index.html"'));
      expect(index, contains('href="lib/index.html"'));
      expect(
        File(
          p.join(reportDir.path, 'absolute', 'lib', 'a.dart.html'),
        ).readAsStringSync(),
        contains('void absolute() {}'),
      );
      expect(
        File(p.join(reportDir.path, 'lib', 'b.dart.html')).readAsStringSync(),
        contains('void relative() {}'),
      );
    });

    test('avoids the absolute report folder when that name is a source', () {
      final directory = Directory.systemTemp.createTempSync('coverde-html-');
      addTearDown(() => directory.deleteSync(recursive: true));
      File(p.join(directory.path, 'absolute', 'a.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync('void namespaced() {}\n');
      final previous = Directory.current;
      Directory.current = directory;
      addTearDown(() => Directory.current = previous);
      final reportDir = Directory(p.join(directory.path, 'html'));
      final root = buildCoverageTree([
        sourceFile(
          path: 'absolute/a.dart',
          lines: const [CoverageLine(number: 1, hits: 1)],
        ),
        sourceFile(
          path: '/b.dart',
          lines: const [CoverageLine(number: 1, hits: 0)],
        ),
      ]);
      final outer = Zone.current;

      IOOverrides.runZoned(
        () => generate(root, reportDir),
        createFile: (filePath) {
          if (filePath == '/b.dart') {
            return _SourceFile(filePath, const ['void root() {}']);
          }
          return outer.run(() => File(filePath));
        },
      );

      expect(
        File(
          p.join(reportDir.path, 'absolute', 'a.dart.html'),
        ).readAsStringSync(),
        contains('void namespaced() {}'),
      );
      expect(
        File(
          p.join(reportDir.path, 'absolute-2', 'b.dart.html'),
        ).readAsStringSync(),
        contains('void root() {}'),
      );
    });

    test('rejects a report path that leaves the output directory', () {
      final directory = Directory.systemTemp.createTempSync('coverde-html-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final reportDir = Directory(p.join(directory.path, 'html'));
      final root = CoverageDirectory(
        path: 'lib/src',
        directories: const [],
        files: [sourceFile(path: 'other/a.dart')],
      );

      expect(
        () => generate(root, reportDir),
        throwsA(
          isA<GenerateHtmlCoverageReportOutsideDirectoryFailure>().having(
            (failure) => failure.sourcePath,
            'sourcePath',
            contains('..'),
          ),
        ),
      );
    });

    test('throws when the source file cannot be read', () {
      final directory = Directory.systemTemp.createTempSync('coverde-html-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final previous = Directory.current;
      Directory.current = directory;
      addTearDown(() => Directory.current = previous);
      final reportDir = Directory(p.join(directory.path, 'html'));
      final root = CoverageDirectory(
        path: '',
        directories: const [],
        files: [
          sourceFile(
            path: 'missing.dart',
            lines: const [CoverageLine(number: 1, hits: 0)],
          ),
        ],
      );

      expect(
        () => generate(root, reportDir),
        throwsA(isA<GenerateHtmlCoverageReportFileReadFailure>()),
      );
    });

    test('throws when a report file cannot be created', () {
      final directory = Directory.systemTemp.createTempSync('coverde-html-');
      addTearDown(() => directory.deleteSync(recursive: true));
      File(
        p.join(directory.path, 'a.dart'),
      ).writeAsStringSync('void main() {}\n');
      final previous = Directory.current;
      Directory.current = directory;
      addTearDown(() => Directory.current = previous);
      final reportDir = Directory(p.join(directory.path, 'html'));
      final root = CoverageDirectory(
        path: '',
        directories: const [],
        files: [
          sourceFile(
            path: 'a.dart',
            lines: const [CoverageLine(number: 1, hits: 1)],
          ),
        ],
      );
      final outer = Zone.current;

      expect(
        () => IOOverrides.runZoned(
          () => generate(root, reportDir),
          createFile: (filePath) {
            if (filePath.endsWith('.html')) {
              return _FailingFile(filePath, createMessage: 'cannot create');
            }
            return outer.run(() => File(filePath));
          },
        ),
        throwsA(isA<GenerateHtmlCoverageReportFileCreateFailure>()),
      );
    });

    test('throws when a report file cannot be written', () {
      final directory = Directory.systemTemp.createTempSync('coverde-html-');
      addTearDown(() => directory.deleteSync(recursive: true));
      File(
        p.join(directory.path, 'a.dart'),
      ).writeAsStringSync('void main() {}\n');
      final previous = Directory.current;
      Directory.current = directory;
      addTearDown(() => Directory.current = previous);
      final reportDir = Directory(p.join(directory.path, 'html'));
      final root = CoverageDirectory(
        path: '',
        directories: const [],
        files: [
          sourceFile(
            path: 'a.dart',
            lines: const [CoverageLine(number: 1, hits: 1)],
          ),
        ],
      );
      final outer = Zone.current;

      expect(
        () => IOOverrides.runZoned(
          () => generate(root, reportDir),
          createFile: (filePath) {
            if (filePath.endsWith('.html')) {
              return _FailingFile(filePath, writeMessage: 'cannot write');
            }
            return outer.run(() => File(filePath));
          },
        ),
        throwsA(isA<GenerateHtmlCoverageReportFileWriteFailure>()),
      );
    });

    test('throws when a report asset cannot be written', () {
      final directory = Directory.systemTemp.createTempSync('coverde-html-');
      addTearDown(() => directory.deleteSync(recursive: true));
      File(
        p.join(directory.path, 'a.dart'),
      ).writeAsStringSync('void main() {}\n');
      final previous = Directory.current;
      Directory.current = directory;
      addTearDown(() => Directory.current = previous);
      final reportDir = Directory(p.join(directory.path, 'html'));
      final root = CoverageDirectory(
        path: '',
        directories: const [],
        files: [
          sourceFile(
            path: 'a.dart',
            lines: const [CoverageLine(number: 1, hits: 1)],
          ),
        ],
      );
      final outer = Zone.current;

      expect(
        () => IOOverrides.runZoned(
          () => generate(root, reportDir),
          createFile: (filePath) {
            if (filePath.endsWith('.css')) {
              return _FailingFile(filePath, bytesMessage: 'cannot write bytes');
            }
            return outer.run(() => File(filePath));
          },
        ),
        throwsA(isA<GenerateHtmlCoverageReportFileWriteFailure>()),
      );
    });
  });
}

final class _SourceFile extends Fake implements File {
  _SourceFile(this.path, this.lines);

  @override
  final String path;

  final List<String> lines;

  @override
  List<String> readAsLinesSync({Encoding encoding = utf8}) => lines;
}

final class _FailingFile extends Fake implements File {
  _FailingFile(
    this.path, {
    this.createMessage,
    this.writeMessage,
    this.bytesMessage,
  });

  @override
  final String path;

  final String? createMessage;
  final String? writeMessage;
  final String? bytesMessage;

  @override
  void createSync({bool recursive = false, bool exclusive = false}) {
    final message = createMessage;
    if (message != null) throw FileSystemException(message, path);
  }

  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    final message = writeMessage;
    if (message != null) throw FileSystemException(message, path);
  }

  @override
  void writeAsBytesSync(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) {
    final message = bytesMessage;
    if (message != null) throw FileSystemException(message, path);
  }
}
