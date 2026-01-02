import 'package:coverde/src/commands/value/failures.dart';
import 'package:test/test.dart';

void main() {
  group('$CoverdeValueFailure', () {
    group('$CoverdeValueTraceFileNotFoundFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with trace file path',
        () {
          const failure = CoverdeValueTraceFileNotFoundFailure(
            traceFilePath: '/path/to/trace.lcov.info',
          );

          final result = failure.readableMessage;

          expect(result, 'No trace file found at `/path/to/trace.lcov.info`.');
        },
      );

      test(
        'traceFilePath '
        '| returns the trace file path',
        () {
          const failure = CoverdeValueTraceFileNotFoundFailure(
            traceFilePath: '/path/to/file',
          );

          final result = failure.traceFilePath;

          expect(result, '/path/to/file');
        },
      );
    });

    group('$CoverdeValueEmptyTraceFileFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with trace file path',
        () {
          const failure = CoverdeValueEmptyTraceFileFailure(
            traceFilePath: '/path/to/trace.lcov.info',
          );

          final result = failure.readableMessage;

          expect(
            result,
            'No coverage data found in the trace file at '
            '`/path/to/trace.lcov.info`.',
          );
        },
      );

      test(
        'traceFilePath '
        '| returns the trace file path',
        () {
          const failure = CoverdeValueEmptyTraceFileFailure(
            traceFilePath: '/path/to/file',
          );

          final result = failure.traceFilePath;

          expect(result, '/path/to/file');
        },
      );
    });
  });
}
