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
          final result = exception.code;

          expect(result, ExitCode.data);
        },
      );

      test(
        'toString() '
        '| string representation includes exception message',
        () {
          final result = exception.toString();

          expect(result, 'A message.');
        },
      );
    },
  );
}
