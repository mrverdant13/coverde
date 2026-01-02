import 'package:coverde/src/commands/filter/failures.dart';
import 'package:test/test.dart';

void main() {
  group('$CoverdeFilterFailure', () {
    group('$CoverdeFilterInvalidRegexPatternFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with invalid regex pattern and exception',
        () {
          const exception = FormatException('Invalid regex pattern');
          const failure = CoverdeFilterInvalidRegexPatternFailure(
            usageMessage: 'Usage message',
            invalidRegexPattern: '[invalid',
            exception: exception,
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
Invalid regex pattern: `[invalid`.
Invalid regex pattern

Usage message
''',
          );
        },
      );

      test(
        'invalidInputDescription '
        '| returns formatted description with pattern and exception message',
        () {
          const exception = FormatException('Unmatched bracket');
          const failure = CoverdeFilterInvalidRegexPatternFailure(
            usageMessage: 'Usage message',
            invalidRegexPattern: '[unclosed',
            exception: exception,
          );

          final result = failure.invalidInputDescription;

          expect(
            result,
            'Invalid regex pattern: `[unclosed`.\n'
            'Unmatched bracket',
          );
        },
      );

      test(
        'invalidRegexPattern '
        '| returns the invalid regex pattern',
        () {
          const exception = FormatException('Error');
          const failure = CoverdeFilterInvalidRegexPatternFailure(
            usageMessage: 'Usage message',
            invalidRegexPattern: 'test[pattern',
            exception: exception,
          );

          final result = failure.invalidRegexPattern;

          expect(result, 'test[pattern');
        },
      );

      test(
        'exception '
        '| returns the underlying FormatException',
        () {
          const exception = FormatException('Custom error message');
          const failure = CoverdeFilterInvalidRegexPatternFailure(
            usageMessage: 'Usage message',
            invalidRegexPattern: 'pattern',
            exception: exception,
          );

          final result = failure.exception;

          expect(result, exception);
          expect(result.message, 'Custom error message');
        },
      );
    });

    group('$CoverdeFilterTraceFileNotFoundFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with trace file path',
        () {
          const failure = CoverdeFilterTraceFileNotFoundFailure(
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
          const failure = CoverdeFilterTraceFileNotFoundFailure(
            traceFilePath: '/path/to/file',
          );

          final result = failure.traceFilePath;

          expect(result, '/path/to/file');
        },
      );
    });
  });
}
