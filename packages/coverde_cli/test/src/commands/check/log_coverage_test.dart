import 'package:coverde/src/commands/check/log_coverage.dart';
import 'package:coverde/src/commands/report/failures.dart';
import 'package:coverde/src/entities/coverage_document.dart';
import 'package:coverde/src/entities/file_coverage_log_level.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

final class _MockLogger extends Mock implements Logger {}

void main() {
  test('line-content rejects a coverage path this host cannot open', () {
    final sourcePath = Platform.isWindows ? '/lib/a.dart' : r'C:\lib\a.dart';
    final document = CoverageDocument.parse('''
SF:$sourcePath
DA:1,0
end_of_record
''');

    expect(
      () => logCoverage(
        logger: _MockLogger(),
        document: document,
        fileCoverageLogLevel: FileCoverageLogLevel.lineContent,
      ),
      throwsA(isA<CoverdeReportUnresolvedCoveragePathFailure>()),
    );
  });

  test('line-content rejects a missing source file', () {
    final document = CoverageDocument.parse('''
SF:lib/missing.dart
DA:1,0
end_of_record
''');

    expect(
      () => logCoverage(
        logger: _MockLogger(),
        document: document,
        fileCoverageLogLevel: FileCoverageLogLevel.lineContent,
      ),
      throwsA(isA<CoverdeReportFileReadFailure>()),
    );
  });
}
