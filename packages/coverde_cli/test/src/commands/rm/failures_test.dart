import 'package:coverde/src/commands/rm/failures.dart';
import 'package:test/test.dart';

void main() {
  group('$CoverdeRmFailure', () {
    group('$CoverdeRmMissingPathsFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with usage',
        () {
          const failure = CoverdeRmMissingPathsFailure(
            usageMessage: 'Usage message',
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
A set of file and/or directory paths should be provided.

Usage message
''',
          );
        },
      );

      test(
        'invalidInputDescription '
        '| returns the invalid input description',
        () {
          const failure = CoverdeRmMissingPathsFailure(
            usageMessage: 'Usage message',
          );

          final result = failure.invalidInputDescription;

          expect(
            result,
            'A set of file and/or directory paths should be provided.',
          );
        },
      );
    });

    group('$CoverdeRmElementNotFoundFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with element path',
        () {
          const failure = CoverdeRmElementNotFoundFailure(
            elementPath: '/path/to/element',
          );

          final result = failure.readableMessage;

          expect(result, 'The </path/to/element> element does not exist.');
        },
      );

      test(
        'elementPath '
        '| returns the element path',
        () {
          const failure = CoverdeRmElementNotFoundFailure(
            elementPath: '/path/to/file',
          );

          final result = failure.elementPath;

          expect(result, '/path/to/file');
        },
      );
    });
  });
}
