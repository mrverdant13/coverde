import 'package:coverde/src/entities/coverage_trace_format_failure.dart';
import 'package:coverde/src/entities/coverde_failure.dart';
import 'package:test/test.dart';

void main() {
  group('$CoverageTraceFormatFailure', () {
    test('exposes the readable message', () {
      const failure = CoverageTraceFormatFailure(
        readableMessage: 'Trace file contains an empty record.',
      );

      expect(failure, isA<CoverdeFailure>());
      expect(failure.readableMessage, 'Trace file contains an empty record.');
    });
  });
}
