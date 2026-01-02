import 'package:coverde/src/commands/optimize_tests/failures.dart';
import 'package:test/test.dart';

void main() {
  group('$CoverdeOptimizeTestsFailure', () {
    group('$CoverdeOptimizeTestsPubspecNotFoundFailure', () {
      test(
        'readableMessage '
        '| returns formatted message with project directory path',
        () {
          const failure = CoverdeOptimizeTestsPubspecNotFoundFailure(
            usageMessage: 'Usage message',
            projectDirPath: '/path/to/project',
          );

          final result = failure.readableMessage;

          expect(
            result,
            '''
No pubspec.yaml file found in /path/to/project.

Usage message
''',
          );
        },
      );

      test(
        'projectDirPath '
        '| returns the project directory path',
        () {
          const failure = CoverdeOptimizeTestsPubspecNotFoundFailure(
            usageMessage: 'Usage message',
            projectDirPath: '/path/to/project',
          );

          final result = failure.projectDirPath;

          expect(result, '/path/to/project');
        },
      );

      test(
        'invalidInputDescription '
        '| returns the invalid input description',
        () {
          const failure = CoverdeOptimizeTestsPubspecNotFoundFailure(
            usageMessage: 'Usage message',
            projectDirPath: '/path/to/project',
          );

          final result = failure.invalidInputDescription;

          expect(result, 'No pubspec.yaml file found in /path/to/project.');
        },
      );
    });
  });
}
