import 'package:coverde/src/utils/path.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeCoveragePath', () {
    test('keeps the separator the path already uses', () {
      expect(normalizeCoveragePath(r'lib\app.dart'), r'lib\app.dart');
      expect(normalizeCoveragePath('lib/app.dart'), 'lib/app.dart');
      expect(normalizeCoveragePath(r'.\a.dart'), 'a.dart');
      expect(normalizeCoveragePath('./a.dart'), 'a.dart');
    });

    test('keeps the first separator when both appear', () {
      expect(normalizeCoveragePath(r'C:\src/foo\..\a.dart'), r'C:\src\a.dart');
      expect(normalizeCoveragePath(r'lib\foo/../a.dart'), r'lib\a.dart');
      expect(normalizeCoveragePath(r'lib/foo\../a.dart'), 'lib/a.dart');
    });

    test('drops dot and empty segments', () {
      expect(normalizeCoveragePath('./a.dart'), 'a.dart');
      expect(normalizeCoveragePath('lib/./a.dart'), 'lib/a.dart');
      expect(normalizeCoveragePath('lib//a.dart'), 'lib/a.dart');
      expect(normalizeCoveragePath('lib/a.dart/'), 'lib/a.dart');
      expect(normalizeCoveragePath('foo/..'), '.');
      expect(normalizeCoveragePath('/'), '/');
    });

    test('resolves parent segments below a normal root', () {
      expect(normalizeCoveragePath('lib/../a.dart'), 'a.dart');
      expect(normalizeCoveragePath(r'lib\..\a.dart'), 'a.dart');
      expect(normalizeCoveragePath('/foo/../a.dart'), '/a.dart');
      expect(normalizeCoveragePath('/foo/../../a.dart'), '/a.dart');
      expect(normalizeCoveragePath('../shared/b.dart'), '../shared/b.dart');
      expect(normalizeCoveragePath('../../a.dart'), '../../a.dart');
    });

    test('keeps a drive root', () {
      expect(normalizeCoveragePath('C:/src/../../a.dart'), 'C:/a.dart');
      expect(normalizeCoveragePath(r'C:\src\..\..\a.dart'), r'C:\a.dart');
      expect(normalizeCoveragePath('C:/'), 'C:/');
      expect(normalizeCoveragePath(r'C:\'), r'C:\');
      expect(normalizeCoveragePath('C:'), 'C:');
    });

    test('keeps a drive-relative prefix', () {
      expect(normalizeCoveragePath('C:src/../a.dart'), 'C:a.dart');
      expect(normalizeCoveragePath(r'C:src\..\a.dart'), 'C:a.dart');
      expect(normalizeCoveragePath('C:../a.dart'), 'C:../a.dart');
      expect(normalizeCoveragePath('C:a.dart'), 'C:a.dart');
      expect(normalizeCoveragePath('C:src/..'), 'C:.');
    });

    test('keeps a UNC root', () {
      expect(
        normalizeCoveragePath(r'\\server\share\a.dart'),
        r'\\server\share\a.dart',
      );
      expect(
        normalizeCoveragePath('//server/share/foo/../a.dart'),
        '//server/share/a.dart',
      );
      expect(
        normalizeCoveragePath(r'\\server\share\..\a.dart'),
        r'\\server\share\a.dart',
      );
      expect(normalizeCoveragePath(r'\\server\share'), r'\\server\share');
      expect(normalizeCoveragePath('//server/share'), '//server/share');
    });
  });

  group('coveragePathRoot', () {
    test('classifies each root', () {
      expect(coveragePathRoot('lib/a.dart'), CoveragePathRoot.relative);
      expect(coveragePathRoot('/a.dart'), CoveragePathRoot.posixAbsolute);
      expect(coveragePathRoot('C:/a.dart'), CoveragePathRoot.drive);
      expect(coveragePathRoot('C:'), CoveragePathRoot.drive);
      expect(coveragePathRoot('C:.'), CoveragePathRoot.driveRelative);
      expect(coveragePathRoot('C:a.dart'), CoveragePathRoot.driveRelative);
      expect(coveragePathRoot(r'\\server\share\a.dart'), CoveragePathRoot.unc);
    });
  });

  group('hostCanResolveCoveragePath', () {
    test('accepts a relative path on either host', () {
      expect(
        hostCanResolveCoveragePath('lib/a.dart', windowsHost: false),
        isTrue,
      );
      expect(
        hostCanResolveCoveragePath('lib/a.dart', windowsHost: true),
        isTrue,
      );
    });

    test('rejects a Windows root on a POSIX host', () {
      expect(
        hostCanResolveCoveragePath('C:/a.dart', windowsHost: false),
        isFalse,
      );
      expect(
        hostCanResolveCoveragePath('C:a.dart', windowsHost: false),
        isFalse,
      );
      expect(
        hostCanResolveCoveragePath(
          r'\\server\share\a.dart',
          windowsHost: false,
        ),
        isFalse,
      );
    });

    test('rejects a POSIX absolute path on a Windows host', () {
      expect(hostCanResolveCoveragePath('/a.dart', windowsHost: true), isFalse);
      expect(
        hostCanResolveCoveragePath('C:/a.dart', windowsHost: true),
        isTrue,
      );
      expect(hostCanResolveCoveragePath('/a.dart', windowsHost: false), isTrue);
    });
  });
}
