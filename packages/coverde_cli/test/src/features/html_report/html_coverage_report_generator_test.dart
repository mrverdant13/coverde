import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/features/html_report/html_coverage_report_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('coverageReportRelativePath', () {
    test('places a POSIX-absolute path under absolute', () {
      expect(
        coverageReportRelativePath(
          sourcePaths: const ['lib/b.dart', '/lib/a.dart'],
          sourcePath: '/lib/a.dart',
        ),
        'absolute/lib/a.dart',
      );
    });

    test('skips folder names that are already taken', () {
      expect(
        coverageReportRelativePath(
          sourcePaths: const [
            'absolute/a.dart',
            'absolute-2/c.dart',
            '/b.dart',
          ],
          sourcePath: '/b.dart',
        ),
        'absolute-3/b.dart',
      );
    });

    test('uses absolute-2 when absolute is a source path', () {
      expect(
        coverageReportRelativePath(
          sourcePaths: const ['absolute/a.dart', '/b.dart'],
          sourcePath: '/b.dart',
        ),
        'absolute-2/b.dart',
      );
    });

    test('places a drive root under drive-c', () {
      expect(
        coverageReportRelativePath(
          sourcePaths: const ['lib/b.dart', 'C:/src/a.dart'],
          sourcePath: 'C:/src/a.dart',
        ),
        'drive-c/src/a.dart',
      );
      expect(
        coverageReportRelativePath(
          sourcePaths: const [r'lib\b.dart', r'C:\src\a.dart'],
          sourcePath: r'C:\src\a.dart',
        ),
        'drive-c/src/a.dart',
      );
    });

    test('keeps a shared drive root without a drive folder', () {
      expect(
        coverageReportRelativePath(
          sourcePaths: const ['C:/proj/lib/a.dart', 'C:/proj/lib/b.dart'],
          sourcePath: 'C:/proj/lib/a.dart',
          from: 'C:/proj',
        ),
        'lib/a.dart',
      );
      expect(
        coverageReportRelativePath(
          sourcePaths: const [r'C:\proj\lib\a.dart', r'C:\proj\lib\b.dart'],
          sourcePath: r'C:\proj\lib\a.dart',
          from: r'C:\proj',
        ),
        'lib/a.dart',
      );
    });

    test('keeps a drive-relative path beside the drive root', () {
      expect(
        coverageReportRelativePath(
          sourcePaths: const ['C:/a.dart', 'C:a.dart'],
          sourcePath: 'C:a.dart',
        ),
        'drive-c-relative/a.dart',
      );
      expect(
        coverageReportRelativePath(
          sourcePaths: const ['C:/a.dart', 'C:a.dart'],
          sourcePath: 'C:/a.dart',
        ),
        'drive-c/a.dart',
      );
    });

    test('places each drive letter in its own folder', () {
      expect(
        coverageReportRelativePath(
          sourcePaths: const ['C:/a.dart', 'D:/b.dart'],
          sourcePath: 'D:/b.dart',
        ),
        'drive-d/b.dart',
      );
    });

    test('places a UNC path beside a POSIX-absolute path', () {
      expect(
        coverageReportRelativePath(
          sourcePaths: const ['//server/share/a.dart', '/server/share/b.dart'],
          sourcePath: '//server/share/a.dart',
        ),
        'unc-server-share/a.dart',
      );
      expect(
        coverageReportRelativePath(
          sourcePaths: const [r'\\server\share\a.dart', '/server/share/b.dart'],
          sourcePath: r'\\server\share\a.dart',
        ),
        'unc-server-share/a.dart',
      );
      expect(
        coverageReportRelativePath(
          sourcePaths: const ['//server/share/a.dart', '/server/share/b.dart'],
          sourcePath: '/server/share/b.dart',
        ),
        'absolute/server/share/b.dart',
      );
    });

    test('keeps a shared UNC root without a UNC folder', () {
      expect(
        coverageReportRelativePath(
          sourcePaths: const [
            '//server/share/proj/a.dart',
            '//server/share/proj/b.dart',
          ],
          sourcePath: '//server/share/proj/a.dart',
          from: '//server/share/proj',
        ),
        'a.dart',
      );
    });
  });

  group('HtmlCoverageReportGenerator', () {
    test('rejects a path that leaves the report directory', () {
      final reportDir = Directory.systemTemp.createTempSync(
        'coverde-html-report-',
      );
      addTearDown(() => reportDir.deleteSync(recursive: true));
      final sourcePath = p.join(reportDir.path, 'lib', 'a.dart');
      File(sourcePath)
        ..createSync(recursive: true)
        ..writeAsStringSync('void library() {}\n');
      final tree = CovDir.tree(
        covFiles: [
          CovFile.parse('SF:$sourcePath\nDA:1,1'),
          CovFile.parse('SF:../shared/b.dart\nDA:1,0'),
        ],
      );

      expect(
        () => const HtmlCoverageReportGenerator().generate(
          root: tree,
          traceFileName: 'lcov.info',
          parentReportDirAbsPath: reportDir.path,
          traceFileModificationDate: DateTime.utc(2026),
          medium: 80,
          high: 90,
        ),
        throwsA(
          isA<GenerateHtmlCoverageReportOutsideDirectoryFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('would be written outside the report directory'),
          ),
        ),
      );
    });

    test('rejects a source path this host cannot read', () {
      final reportDir = Directory.systemTemp.createTempSync(
        'coverde-html-report-',
      );
      addTearDown(() => reportDir.deleteSync(recursive: true));
      final sourcePath = Platform.isWindows ? '/abs/a.dart' : 'C:/a.dart';
      final tree = CovDir.tree(
        covFiles: [CovFile.parse('SF:$sourcePath\nDA:1,1')],
      );

      expect(
        () => const HtmlCoverageReportGenerator().generate(
          root: tree,
          traceFileName: 'lcov.info',
          parentReportDirAbsPath: reportDir.path,
          traceFileModificationDate: DateTime.utc(2026),
          medium: 80,
          high: 90,
        ),
        throwsA(
          isA<GenerateHtmlCoverageReportUnresolvedCoveragePathFailure>().having(
            (failure) => failure.readableMessage,
            'readableMessage',
            contains('cannot be resolved on this operating system'),
          ),
        ),
      );
    });
  });
}
