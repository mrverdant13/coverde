import 'package:coverde/src/entities/cov_file_format.exception.dart';
import 'package:io/io.dart';
import 'package:test/test.dart';

void main() {
  group(
    '$CovFileFormatException',
    () {
      final exception = CovFileFormatException(message: 'A message.');

      test(
        'code '
        '| returns data exit code',
        () {
          // ACT
          final result = exception.code;

          // ASSERT
          expect(result, ExitCode.data);
        },
      );

      test(
        'toString() '
        '| string representation includes exception message',
        () {
          // ACT
          final result = exception.toString();

          // ASSERT
          expect(result, 'A message.');
        },
      );
    },
  );
}
