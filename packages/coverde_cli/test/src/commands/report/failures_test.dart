import 'package:coverde/src/commands/report/failures.dart';
import 'package:test/test.dart';

void main() {
  group('$CoverdeReportFailure', () {
    group('$CoverdeReportInvalidMediumThresholdFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with invalid raw value',
        () {
          const failure = CoverdeReportInvalidMediumThresholdFailure(
            usageMessage: 'Usage message',
            rawValue: 'invalid',
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
Invalid medium threshold: `invalid`.
It should be a positive number not greater than 100 [0.0, 100.0].

Usage message
''',
          );
        },
      );

      test(
        'rawValue '
        '| returns the raw value',
        () {
          const failure = CoverdeReportInvalidMediumThresholdFailure(
            usageMessage: 'Usage message',
            rawValue: 'test',
          );

          final result = failure.rawValue;

          expect(result, 'test');
        },
      );
    });

    group('$CoverdeReportInvalidHighThresholdFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with invalid raw value',
        () {
          const failure = CoverdeReportInvalidHighThresholdFailure(
            usageMessage: 'Usage message',
            rawValue: 'invalid',
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
Invalid high threshold: `invalid`.
It should be a positive number not greater than 100 [0.0, 100.0].

Usage message
''',
          );
        },
      );

      test(
        'rawValue '
        '| returns the raw value',
        () {
          const failure = CoverdeReportInvalidHighThresholdFailure(
            usageMessage: 'Usage message',
            rawValue: 'test',
          );

          final result = failure.rawValue;

          expect(result, 'test');
        },
      );
    });

    group('$CoverdeReportInvalidThresholdRelationshipFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with threshold values',
        () {
          const failure = CoverdeReportInvalidThresholdRelationshipFailure(
            usageMessage: 'Usage message',
            mediumValue: 90,
            highValue: 75,
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
Medium threshold (90.0) must be less than high threshold (75.0).

Usage message
''',
          );
        },
      );

      test(
        'mediumValue '
        '| returns the medium value',
        () {
          const failure = CoverdeReportInvalidThresholdRelationshipFailure(
            usageMessage: 'Usage message',
            mediumValue: 80,
            highValue: 90,
          );

          final result = failure.mediumValue;

          expect(result, 80);
        },
      );

      test(
        'highValue '
        '| returns the high value',
        () {
          const failure = CoverdeReportInvalidThresholdRelationshipFailure(
            usageMessage: 'Usage message',
            mediumValue: 80,
            highValue: 90,
          );

          final result = failure.highValue;

          expect(result, 90);
        },
      );
    });

    group('$CoverdeReportTraceFileNotFoundFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with trace file path',
        () {
          const failure = CoverdeReportTraceFileNotFoundFailure(
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
          const failure = CoverdeReportTraceFileNotFoundFailure(
            traceFilePath: '/path/to/file',
          );

          final result = failure.traceFilePath;

          expect(result, '/path/to/file');
        },
      );
    });

    group('$CoverdeReportEmptyTraceFileFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with trace file path',
        () {
          const failure = CoverdeReportEmptyTraceFileFailure(
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
          const failure = CoverdeReportEmptyTraceFileFailure(
            traceFilePath: '/path/to/file',
          );

          final result = failure.traceFilePath;

          expect(result, '/path/to/file');
        },
      );
    });
  });
}
