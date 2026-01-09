import 'package:coverde/src/entities/cov_file_format.exception.dart';
import 'package:test/test.dart';

void main() {
  group(
    '$CovFileFormatFailure',
    () {
      const exception = CovFileFormatFailure(readableMessage: 'A message.');

      test(
        'readableMessage '
        '| returns the readable message',
        () {
          final result = exception.readableMessage;

          expect(result, 'A message.');
        },
      );
    },
  );
}
