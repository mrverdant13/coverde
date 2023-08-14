import 'package:coverde/src/entities/cov_file_format.exception.dart';
import 'package:io/io.dart';
import 'package:test/test.dart';

void main() {
  group(
    '''

GIVEN a cov-file format exception''',
    () {
      // ARRANGE
      final exception = CovFileFormatException(message: 'A message.');

      test(
        '''
WHEN its exit code is requested
THEN the data code should be returned
''',
        () {
          // ACT
          final result = exception.code;

          // ASSERT
          expect(result, ExitCode.data);
        },
      );

      test(
        '''
WHEN its string representation is requested
THEN a string holding the exception details should be returned
''',
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
