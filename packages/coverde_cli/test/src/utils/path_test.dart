import 'package:coverde/src/utils/path.dart';
import 'package:test/test.dart';

void main() {
  group('normalizePosixPath', () {
    test('uses slash separators', () {
      expect(normalizePosixPath(r'lib\src\a.dart'), 'lib/src/a.dart');
      expect(normalizePosixPath(r'C:\src\a.dart'), 'C:/src/a.dart');
    });

    test('drops dot and empty segments', () {
      expect(normalizePosixPath('./a.dart'), 'a.dart');
      expect(normalizePosixPath('lib/./a.dart'), 'lib/a.dart');
      expect(normalizePosixPath('lib//a.dart/'), 'lib/a.dart');
      expect(normalizePosixPath(''), '.');
      expect(normalizePosixPath('/'), '/');
    });

    test('resolves parent segments', () {
      expect(normalizePosixPath('lib/../src/a.dart'), 'src/a.dart');
      expect(normalizePosixPath('foo/../../b.dart'), '../b.dart');
      expect(normalizePosixPath('/foo/../a.dart'), '/a.dart');
      expect(normalizePosixPath('../shared/b.dart'), '../shared/b.dart');
    });

    test('keeps a leading slash', () {
      expect(normalizePosixPath('/external.dart'), '/external.dart');
    });

    test('resolves parent segments below a normal root', () {
      expect(normalizePosixPath('lib/../a.dart'), 'a.dart');
      expect(normalizePosixPath('/foo/../a.dart'), '/a.dart');
    });

    test('keeps a drive root', () {
      expect(normalizePosixPath('C:/src/../../a.dart'), 'C:/a.dart');
      expect(normalizePosixPath(r'C:\src\..\..\a.dart'), 'C:/a.dart');
    });

    test('keeps a drive-relative prefix', () {
      expect(normalizePosixPath('C:src/../a.dart'), 'C:a.dart');
      expect(normalizePosixPath('C:../a.dart'), 'C:../a.dart');
    });

    test('keeps a UNC root', () {
      expect(
        normalizePosixPath(r'\\server\share\a.dart'),
        '//server/share/a.dart',
      );
      expect(
        normalizePosixPath('//server/share/foo/../a.dart'),
        '//server/share/a.dart',
      );
      expect(
        normalizePosixPath(r'\\server\share\..\a.dart'),
        '//server/share/a.dart',
      );
    });
  });
}
