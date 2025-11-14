import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:coverde/src/commands/optimize_tests/optimize_tests.dart';
import 'package:dart_style/dart_style.dart';
import 'package:io/ansi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../helpers/test_files.dart';
import '../../../utils/mocks.dart';

final String _expectedUsage = '''
Optimize tests by gathering them.

Usage: coverde optimize-tests [arguments]
-h, --help                    Print this usage information.
    --include                 The glob pattern for the tests files to include.
                              (defaults to "test/**_test.dart")
    --exclude                 The glob pattern for the tests files to exclude.
    --output                  The path to the optimized tests file.
                              (defaults to "test/optimized_test.dart")
    --[no-]flutter-goldens    Whether to use golden tests in case of a Flutter package.
                              (defaults to on)

Run "coverde help" to see global options.
'''
    .trim();

void main() {
  group('coverde optimize-tests', () {
    late CommandRunner<void> cmdRunner;
    late MockStdout out;
    late Command<void> command;

    setUp(() {
      cmdRunner = CommandRunner<void>('coverde', 'A tester command runner');
      out = MockStdout();
      when(() => out.supportsAnsiEscapes).thenReturn(true);
      command = OptimizeTestsCommand();
      cmdRunner.addCommand(command);
    });

    tearDown(() {
      verifyNoMoreInteractions(out);
    });

    test('| usage', () {
      final subject = command.usage;
      expect(subject, _expectedUsage);
    });

    test('| fails when no pubspec.yaml is found', () async {
      final currentDirectory = Directory.current;
      final projectPath = p.joinAll([
        'test',
        'src',
        'commands',
        'optimize_tests',
        'fixtures',
        'no_pubspec',
      ]);
      IOOverrides.runZoned(
        () {
          Future<void> action() => cmdRunner.run([
                command.name,
              ]);
          expect(
            action,
            throwsA(
              isA<UsageException>().having(
                (e) => e.message,
                'message',
                contains(
                  'pubspec.yaml not found in '
                  '${p.join(currentDirectory.path, projectPath)}',
                ),
              ),
            ),
          );
        },
        getCurrentDirectory: () => Directory(
          p.join(currentDirectory.path, projectPath),
        ),
        stdout: () => out,
      );
    });

    test(
        '''--${OptimizeTestsCommand.outputOptionName}=<output-path-that-starts-with-a-dot> '''
        '| '
        'fails when no pubspec.yaml is found', () async {
      final currentDirectory = Directory.current;
      final projectTypes = ['flutter', 'dart'];
      for (final projectType in projectTypes) {
        final projectPath = p.joinAll([
          'test',
          'src',
          'commands',
          'optimize_tests',
          'fixtures',
          '${projectType}_proj_with_no_tests',
        ]);
        final projectTestsDirectory = Directory(p.join(projectPath, 'test'));
        if (projectTestsDirectory.existsSync()) {
          projectTestsDirectory.deleteSync(recursive: true);
        }

        await IOOverrides.runZoned(
          () async {
            await cmdRunner.run([
              command.name,
              '--${OptimizeTestsCommand.outputOptionName}=test/.optimized_test.dart',
            ]);
          },
          getCurrentDirectory: () => Directory(
            p.join(currentDirectory.path, projectPath),
          ),
          stdout: () => out,
        );

        verify(() => out.supportsAnsiEscapes);
        verify(
          () => out.writeln(
            wrapWith(
              'Beware that test files starting with a dot may cause issues '
              'when running them on web platforms.',
              [yellow, styleBold],
            ),
          ),
        ).called(1);
      }
    });

    test(
        '| '
        'generates an empty optimized test file '
        'when no tests are found in a project', () async {
      final currentDirectory = Directory.current;
      final projectTypes = ['flutter', 'dart'];
      for (final projectType in projectTypes) {
        final projectPath = p.joinAll([
          'test',
          'src',
          'commands',
          'optimize_tests',
          'fixtures',
          '${projectType}_proj_with_no_tests',
        ]);
        await IOOverrides.runZoned(
          () async {
            final projectTestsDirectory =
                Directory(p.join(projectPath, 'test'));
            if (projectTestsDirectory.existsSync()) {
              projectTestsDirectory.deleteSync(recursive: true);
            }
            await cmdRunner.run([
              command.name,
            ]);
            final optimizedTestFile = File(
              p.join(projectPath, 'test', 'optimized_test.dart'),
            );
            final optimizedTestFileContent =
                optimizedTestFile.readAsStringSync();
            const expectedOutput = '''
// ignore_for_file: type=lint

void main() {}
''';
            expect(
              optimizedTestFileContent,
              expectedOutput,
              reason: 'no empty optimized test for $projectType project',
            );
            expect(optimizedTestFileContent.hasEmptyMainFunction, isTrue);
          },
          getCurrentDirectory: () => Directory(
            p.join(currentDirectory.path, projectPath),
          ),
          stdout: () => out,
        );
      }
    });

    test(
        '| '
        'generates an optimized test file '
        'ignoring invalid test files', () async {
      final currentDirectory = Directory.current;
      final projectTypes = ['flutter', 'dart'];
      for (final projectType in projectTypes) {
        final projectPath = p.joinAll([
          'test',
          'src',
          'commands',
          'optimize_tests',
          'fixtures',
          '${projectType}_proj_with_invalid_test_files',
        ]);
        final projectDir = Directory(
          p.joinAll([
            currentDirectory.path,
            projectPath,
          ]),
        );
        final optimizedTestFile = File(
          p.join(projectPath, 'test', 'optimized_test.dart'),
        );
        if (optimizedTestFile.existsSync()) {
          optimizedTestFile.deleteSync(recursive: true);
        }

        generateTestFromTemplate(projectDir);
        addTearDown(() => deleteTestFiles(projectDir));

        await IOOverrides.runZoned(
          () async {
            await cmdRunner.run([
              command.name,
            ]);
          },
          getCurrentDirectory: () => Directory(
            p.join(currentDirectory.path, projectPath),
          ),
          stdout: () => out,
        );

        final optimizedTestFileContent = optimizedTestFile.readAsStringSync();
        const expectedOutput = '''
// ignore_for_file: type=lint

void main() {}
''';
        expect(
          optimizedTestFileContent,
          expectedOutput,
          reason: 'optimized test '
              'with invalid test files '
              'for $projectType project',
        );
        expect(optimizedTestFileContent.hasEmptyMainFunction, isTrue);
        final testFilesWithNoMainFunction = [
          ['test', '01', 't01_01_test.dart'],
          ['test', '01', 't01_03_test.dart'],
          ['test', '02', 't02_02_test.dart'],
          ['test', '02', 't02_04_test.dart'],
          ['test', 't02_test.dart'],
          ['test', 't04_test.dart'],
        ];
        for (final testFilePath in testFilesWithNoMainFunction) {
          verify(
            () => out.writeln(
              'Test file ${p.posix.joinAll(testFilePath)} '
              'does not have a `main` function.',
            ),
          ).called(1);
        }
        final testFilesWithMainFunctionWithParams = [
          ['test', '01', 't01_02_test.dart'],
          ['test', '01', 't01_04_test.dart'],
          ['test', '02', 't02_01_test.dart'],
          ['test', '02', 't02_03_test.dart'],
          ['test', 't01_test.dart'],
          ['test', 't03_test.dart'],
        ];
        for (final testFilePath in testFilesWithMainFunctionWithParams) {
          verify(
            () => out.writeln(
              'Test file ${p.posix.joinAll(testFilePath)} '
              'has a `main` function with params.',
            ),
          ).called(1);
        }
      }
    });

    test(
        '--no-${OptimizeTestsCommand.useFlutterGoldenTestsFlagName} '
        '| '
        'generates an optimized test file '
        'with async test entry points', () async {
      final currentDirectory = Directory.current;
      final projectTypes = ['dart', 'flutter'];
      for (final projectType in projectTypes) {
        final projectPath = p.joinAll([
          'test',
          'src',
          'commands',
          'optimize_tests',
          'fixtures',
          '${projectType}_proj_with_async_test_entry_points',
        ]);
        final projectDir = Directory(
          p.joinAll([
            currentDirectory.path,
            projectPath,
          ]),
        );
        final optimizedTestFile = File(
          p.join(projectPath, 'test', 'optimized_test.dart'),
        );
        if (optimizedTestFile.existsSync()) {
          optimizedTestFile.deleteSync(recursive: true);
        }

        generateTestFromTemplate(projectDir);
        addTearDown(() => deleteTestFiles(projectDir));

        await IOOverrides.runZoned(
          () async {
            await cmdRunner.run([
              command.name,
              '--no-${OptimizeTestsCommand.useFlutterGoldenTestsFlagName}',
            ]);
          },
          getCurrentDirectory: () => Directory(
            p.join(currentDirectory.path, projectPath),
          ),
          stdout: () => out,
        );

        final formatter = DartFormatter(
          languageVersion: DartFormatter.latestLanguageVersion,
          trailingCommas: TrailingCommas.preserve,
        );
        final expectedOutput = formatter.format('''
// ignore_for_file: deprecated_member_use, type=lint

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' show unawaited;

import 'package:test_api/test_api.dart';

import 't00_test.dart' as _i1;
import 't01_test.dart' as _i2;
import 't02_test.dart' as _i3;
import 't03_test.dart' as _i4;

void main() {
  group(
    't00_test.dart',
    () {
      _i1.main();
    },
  );
  group(
    't01_test.dart',
    () {
      unawaited(Future.sync(_i2.main));
    },
  );
  group(
    't02_test.dart',
    () {
      unawaited(Future.sync(_i3.main));
    },
  );
  group(
    't03_test.dart',
    () {
      unawaited(Future.sync(_i4.main));
    },
  );
}
''');
        expect(
          optimizedTestFile.existsSync(),
          isTrue,
        );
        expect(
          optimizedTestFile.readAsStringSync(),
          expectedOutput,
          reason: 'optimized test '
              'should generate an optimized test file '
              'with async test entry points '
              'for $projectType project',
        );
        final testFilesWithAsyncMainFunction = [
          ['test', 't01_test.dart'],
          ['test', 't02_test.dart'],
          ['test', 't03_test.dart'],
        ];
        for (final testFilePath in testFilesWithAsyncMainFunction) {
          verify(
            () => out.writeln(
              'Test file ${p.posix.joinAll(testFilePath)} '
              'has an async `main` function.',
            ),
          ).called(1);
        }
      }
    });

    test(
        '--no-${OptimizeTestsCommand.useFlutterGoldenTestsFlagName} '
        '| '
        'generates an optimized test file '
        'preserving annotations', () async {
      final currentDirectory = Directory.current;
      final projectTypes = ['flutter', 'dart'];
      for (final projectType in projectTypes) {
        final projectPath = p.joinAll([
          'test',
          'src',
          'commands',
          'optimize_tests',
          'fixtures',
          '${projectType}_proj_with_annotated_test_files',
        ]);
        final projectDir = Directory(
          p.joinAll([
            currentDirectory.path,
            projectPath,
          ]),
        );
        final optimizedTestFile = File(
          p.join(projectPath, 'test', 'optimized_test.dart'),
        );
        if (optimizedTestFile.existsSync()) {
          optimizedTestFile.deleteSync(recursive: true);
        }

        generateTestFromTemplate(projectDir);
        addTearDown(() => deleteTestFiles(projectDir));

        await IOOverrides.runZoned(
          () async {
            await cmdRunner.run([
              command.name,
              '--no-${OptimizeTestsCommand.useFlutterGoldenTestsFlagName}',
            ]);
          },
          getCurrentDirectory: () => Directory(
            p.join(currentDirectory.path, projectPath),
          ),
          stdout: () => out,
        );

        final formatter = DartFormatter(
          languageVersion: DartFormatter.latestLanguageVersion,
          trailingCommas: TrailingCommas.preserve,
        );
        final expectedOutput = formatter.format('''
// ignore_for_file: deprecated_member_use, type=lint

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:test_api/test_api.dart';

import 'on_platform_01_test.dart' as _i1;
import 'on_platform_02_test.dart' as _i2;
import 'on_platform_03_test.dart' as _i3;
import 'skip_01_test.dart' as _i4;
import 'skip_02_test.dart' as _i5;
import 'tags_01_test.dart' as _i6;
import 'tags_02_test.dart' as _i7;
import 'test_on_01_test.dart' as _i8;
import 'test_on_02_test.dart' as _i9;
import 'test_on_03_test.dart' as _i10;
import 'timeout_01_test.dart' as _i11;
import 'timeout_02_test.dart' as _i12;
import 'timeout_03_test.dart' as _i13;
import 'timeout_04_test.dart' as _i14;

void main() {
  group(
    'on_platform_01_test.dart',
    () {
      _i1.main();
    },
    onPlatform: {},
  );
  group(
    'on_platform_02_test.dart',
    () {
      _i2.main();
    },
    onPlatform: {'windows': Timeout.factor(2)},
  );
  group(
    'on_platform_03_test.dart',
    () {
      _i3.main();
    },
    onPlatform: {
      'windows': Timeout.factor(2),
      'safari': Skip('Some skip reason'),
    },
  );
  group(
    'skip_01_test.dart',
    () {
      _i4.main();
    },
    skip: true,
  );
  group(
    'skip_02_test.dart',
    () {
      _i5.main();
    },
    skip: 'Skip reason',
  );
  group(
    'tags_01_test.dart',
    () {
      _i6.main();
    },
    tags: [],
  );
  group(
    'tags_02_test.dart',
    () {
      _i7.main();
    },
    tags: ['tag-1', 'tag-2'],
  );
  group(
    'test_on_01_test.dart',
    () {
      _i8.main();
    },
    testOn: '',
  );
  group(
    'test_on_02_test.dart',
    () {
      _i9.main();
    },
    testOn: 'vm',
  );
  group(
    'test_on_03_test.dart',
    () {
      _i10.main();
    },
    testOn: 'browser && !chrome',
  );
  group(
    'timeout_01_test.dart',
    () {
      _i11.main();
    },
    timeout: Timeout(null),
  );
  group(
    'timeout_02_test.dart',
    () {
      _i12.main();
    },
    timeout: Timeout(Duration(seconds: 45)),
  );
  group(
    'timeout_03_test.dart',
    () {
      _i13.main();
    },
    timeout: Timeout.factor(1.5),
  );
  group(
    'timeout_04_test.dart',
    () {
      _i14.main();
    },
    timeout: Timeout.none,
  );
}
''');
        expect(
          optimizedTestFile.existsSync(),
          isTrue,
        );
        expect(
          optimizedTestFile.readAsStringSync(),
          expectedOutput,
          reason: 'optimized test '
              'should preserve annotations '
              'for $projectType project',
        );
      }
    });

    test(
        '--${OptimizeTestsCommand.excludeOptionName}=<exclude-glob> '
        '--no-${OptimizeTestsCommand.useFlutterGoldenTestsFlagName} '
        '| '
        'generates an optimized test file '
        'excluding files matching the exclude glob '
        'preserving annotations', () async {
      final currentDirectory = Directory.current;
      final projectTypes = ['flutter', 'dart'];
      for (final projectType in projectTypes) {
        final projectPath = p.joinAll([
          'test',
          'src',
          'commands',
          'optimize_tests',
          'fixtures',
          '${projectType}_proj_with_annotated_test_files',
        ]);
        final projectDir = Directory(
          p.joinAll([
            currentDirectory.path,
            projectPath,
          ]),
        );
        final optimizedTestFile = File(
          p.join(projectPath, 'test', 'optimized_test.dart'),
        );
        if (optimizedTestFile.existsSync()) {
          optimizedTestFile.deleteSync(recursive: true);
        }

        generateTestFromTemplate(projectDir);
        addTearDown(() => deleteTestFiles(projectDir));

        await IOOverrides.runZoned(
          () async {
            await cmdRunner.run([
              command.name,
              '--${OptimizeTestsCommand.excludeOptionName}="**_01_test.dart"',
              '--no-${OptimizeTestsCommand.useFlutterGoldenTestsFlagName}',
            ]);
          },
          getCurrentDirectory: () => Directory(
            p.join(currentDirectory.path, projectPath),
          ),
          stdout: () => out,
        );

        final formatter = DartFormatter(
          languageVersion: DartFormatter.latestLanguageVersion,
          trailingCommas: TrailingCommas.preserve,
        );
        final expectedOutput = formatter.format('''
// ignore_for_file: deprecated_member_use, type=lint

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:test_api/test_api.dart';

import 'on_platform_02_test.dart' as _i1;
import 'on_platform_03_test.dart' as _i2;
import 'skip_02_test.dart' as _i3;
import 'tags_02_test.dart' as _i4;
import 'test_on_02_test.dart' as _i5;
import 'test_on_03_test.dart' as _i6;
import 'timeout_02_test.dart' as _i7;
import 'timeout_03_test.dart' as _i8;
import 'timeout_04_test.dart' as _i9;

void main() {
  group(
    'on_platform_02_test.dart',
    () {
      _i1.main();
    },
    onPlatform: {'windows': Timeout.factor(2)},
  );
  group(
    'on_platform_03_test.dart',
    () {
      _i2.main();
    },
    onPlatform: {
      'windows': Timeout.factor(2),
      'safari': Skip('Some skip reason'),
    },
  );
  group(
    'skip_02_test.dart',
    () {
      _i3.main();
    },
    skip: 'Skip reason',
  );
  group(
    'tags_02_test.dart',
    () {
      _i4.main();
    },
    tags: ['tag-1', 'tag-2'],
  );
  group(
    'test_on_02_test.dart',
    () {
      _i5.main();
    },
    testOn: 'vm',
  );
  group(
    'test_on_03_test.dart',
    () {
      _i6.main();
    },
    testOn: 'browser && !chrome',
  );
  group(
    'timeout_02_test.dart',
    () {
      _i7.main();
    },
    timeout: Timeout(Duration(seconds: 45)),
  );
  group(
    'timeout_03_test.dart',
    () {
      _i8.main();
    },
    timeout: Timeout.factor(1.5),
  );
  group(
    'timeout_04_test.dart',
    () {
      _i9.main();
    },
    timeout: Timeout.none,
  );
}
''');
        expect(
          optimizedTestFile.existsSync(),
          isTrue,
        );
        expect(
          optimizedTestFile.readAsStringSync(),
          expectedOutput,
          reason: 'optimized test '
              'should preserve annotations '
              'for $projectType project',
        );
      }
    });

    test(
        '--${OptimizeTestsCommand.useFlutterGoldenTestsFlagName} '
        '| '
        'generates an optimized test file '
        'preserving annotations and '
        'adding golden tests setup', () async {
      final currentDirectory = Directory.current;
      final projectTypes = ['explicit', 'implicit'];
      for (final projectType in projectTypes) {
        final projectPath = p.joinAll([
          'test',
          'src',
          'commands',
          'optimize_tests',
          'fixtures',
          '''${projectType}_flutter_proj_with_annotated_test_files_and_golden_tests''',
        ]);
        final projectDir = Directory(
          p.joinAll([
            currentDirectory.path,
            projectPath,
          ]),
        );
        final optimizedTestFile = File(
          p.join(projectPath, 'test', 'optimized_test.dart'),
        );
        if (optimizedTestFile.existsSync()) {
          optimizedTestFile.deleteSync(recursive: true);
        }

        generateTestFromTemplate(projectDir);
        addTearDown(() => deleteTestFiles(projectDir));

        await IOOverrides.runZoned(
          () async {
            await cmdRunner.run([
              command.name,
              '--${OptimizeTestsCommand.useFlutterGoldenTestsFlagName}',
            ]);
          },
          getCurrentDirectory: () => Directory(
            p.join(currentDirectory.path, projectPath),
          ),
          stdout: () => out,
        );

        final formatter = DartFormatter(
          languageVersion: DartFormatter.latestLanguageVersion,
          trailingCommas: TrailingCommas.preserve,
        );
        final expectedOutput = formatter.format('''
// ignore_for_file: deprecated_member_use, type=lint

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart' hide group, setUp, tearDown;
import 'package:path/path.dart' as p;
import 'package:test_api/test_api.dart';

import 'on_platform_01_test.dart' as _i1;
import 'on_platform_02_test.dart' as _i2;
import 'on_platform_03_test.dart' as _i3;
import 'skip_01_test.dart' as _i4;
import 'skip_02_test.dart' as _i5;
import 'tags_01_test.dart' as _i6;
import 'tags_02_test.dart' as _i7;
import 'test_on_01_test.dart' as _i8;
import 'test_on_02_test.dart' as _i9;
import 'test_on_03_test.dart' as _i10;
import 'timeout_01_test.dart' as _i11;
import 'timeout_02_test.dart' as _i12;
import 'timeout_03_test.dart' as _i13;
import 'timeout_04_test.dart' as _i14;

void main() {
  group(
    'on_platform_01_test.dart',
    () {
      late GoldenFileComparator initialGoldenFileComparator;

      setUp(() {
        initialGoldenFileComparator = goldenFileComparator;
        goldenFileComparator = _DelegatingGoldenFileComparator(
          goldensDir: Directory('.'),
          delegateGoldenFileComparator: initialGoldenFileComparator,
        );
      });

      tearDown(() {
        goldenFileComparator = initialGoldenFileComparator;
      });

      _i1.main();
    },
    onPlatform: {},
  );
  group(
    'on_platform_02_test.dart',
    () {
      late GoldenFileComparator initialGoldenFileComparator;

      setUp(() {
        initialGoldenFileComparator = goldenFileComparator;
        goldenFileComparator = _DelegatingGoldenFileComparator(
          goldensDir: Directory('.'),
          delegateGoldenFileComparator: initialGoldenFileComparator,
        );
      });

      tearDown(() {
        goldenFileComparator = initialGoldenFileComparator;
      });

      _i2.main();
    },
    onPlatform: {'windows': Timeout.factor(2)},
  );
  group(
    'on_platform_03_test.dart',
    () {
      late GoldenFileComparator initialGoldenFileComparator;

      setUp(() {
        initialGoldenFileComparator = goldenFileComparator;
        goldenFileComparator = _DelegatingGoldenFileComparator(
          goldensDir: Directory('.'),
          delegateGoldenFileComparator: initialGoldenFileComparator,
        );
      });

      tearDown(() {
        goldenFileComparator = initialGoldenFileComparator;
      });

      _i3.main();
    },
    onPlatform: {
      'windows': Timeout.factor(2),
      'safari': Skip('Some skip reason'),
    },
  );
  group(
    'skip_01_test.dart',
    () {
      late GoldenFileComparator initialGoldenFileComparator;

      setUp(() {
        initialGoldenFileComparator = goldenFileComparator;
        goldenFileComparator = _DelegatingGoldenFileComparator(
          goldensDir: Directory('.'),
          delegateGoldenFileComparator: initialGoldenFileComparator,
        );
      });

      tearDown(() {
        goldenFileComparator = initialGoldenFileComparator;
      });

      _i4.main();
    },
    skip: true,
  );
  group(
    'skip_02_test.dart',
    () {
      late GoldenFileComparator initialGoldenFileComparator;

      setUp(() {
        initialGoldenFileComparator = goldenFileComparator;
        goldenFileComparator = _DelegatingGoldenFileComparator(
          goldensDir: Directory('.'),
          delegateGoldenFileComparator: initialGoldenFileComparator,
        );
      });

      tearDown(() {
        goldenFileComparator = initialGoldenFileComparator;
      });

      _i5.main();
    },
    skip: 'Skip reason',
  );
  group(
    'tags_01_test.dart',
    () {
      late GoldenFileComparator initialGoldenFileComparator;

      setUp(() {
        initialGoldenFileComparator = goldenFileComparator;
        goldenFileComparator = _DelegatingGoldenFileComparator(
          goldensDir: Directory('.'),
          delegateGoldenFileComparator: initialGoldenFileComparator,
        );
      });

      tearDown(() {
        goldenFileComparator = initialGoldenFileComparator;
      });

      _i6.main();
    },
    tags: [],
  );
  group(
    'tags_02_test.dart',
    () {
      late GoldenFileComparator initialGoldenFileComparator;

      setUp(() {
        initialGoldenFileComparator = goldenFileComparator;
        goldenFileComparator = _DelegatingGoldenFileComparator(
          goldensDir: Directory('.'),
          delegateGoldenFileComparator: initialGoldenFileComparator,
        );
      });

      tearDown(() {
        goldenFileComparator = initialGoldenFileComparator;
      });

      _i7.main();
    },
    tags: ['tag-1', 'tag-2'],
  );
  group(
    'test_on_01_test.dart',
    () {
      late GoldenFileComparator initialGoldenFileComparator;

      setUp(() {
        initialGoldenFileComparator = goldenFileComparator;
        goldenFileComparator = _DelegatingGoldenFileComparator(
          goldensDir: Directory('.'),
          delegateGoldenFileComparator: initialGoldenFileComparator,
        );
      });

      tearDown(() {
        goldenFileComparator = initialGoldenFileComparator;
      });

      _i8.main();
    },
    testOn: '',
  );
  group(
    'test_on_02_test.dart',
    () {
      late GoldenFileComparator initialGoldenFileComparator;

      setUp(() {
        initialGoldenFileComparator = goldenFileComparator;
        goldenFileComparator = _DelegatingGoldenFileComparator(
          goldensDir: Directory('.'),
          delegateGoldenFileComparator: initialGoldenFileComparator,
        );
      });

      tearDown(() {
        goldenFileComparator = initialGoldenFileComparator;
      });

      _i9.main();
    },
    testOn: 'vm',
  );
  group(
    'test_on_03_test.dart',
    () {
      late GoldenFileComparator initialGoldenFileComparator;

      setUp(() {
        initialGoldenFileComparator = goldenFileComparator;
        goldenFileComparator = _DelegatingGoldenFileComparator(
          goldensDir: Directory('.'),
          delegateGoldenFileComparator: initialGoldenFileComparator,
        );
      });

      tearDown(() {
        goldenFileComparator = initialGoldenFileComparator;
      });

      _i10.main();
    },
    testOn: 'browser && !chrome',
  );
  group(
    'timeout_01_test.dart',
    () {
      late GoldenFileComparator initialGoldenFileComparator;

      setUp(() {
        initialGoldenFileComparator = goldenFileComparator;
        goldenFileComparator = _DelegatingGoldenFileComparator(
          goldensDir: Directory('.'),
          delegateGoldenFileComparator: initialGoldenFileComparator,
        );
      });

      tearDown(() {
        goldenFileComparator = initialGoldenFileComparator;
      });

      _i11.main();
    },
    timeout: Timeout(null),
  );
  group(
    'timeout_02_test.dart',
    () {
      late GoldenFileComparator initialGoldenFileComparator;

      setUp(() {
        initialGoldenFileComparator = goldenFileComparator;
        goldenFileComparator = _DelegatingGoldenFileComparator(
          goldensDir: Directory('.'),
          delegateGoldenFileComparator: initialGoldenFileComparator,
        );
      });

      tearDown(() {
        goldenFileComparator = initialGoldenFileComparator;
      });

      _i12.main();
    },
    timeout: Timeout(Duration(seconds: 45)),
  );
  group(
    'timeout_03_test.dart',
    () {
      late GoldenFileComparator initialGoldenFileComparator;

      setUp(() {
        initialGoldenFileComparator = goldenFileComparator;
        goldenFileComparator = _DelegatingGoldenFileComparator(
          goldensDir: Directory('.'),
          delegateGoldenFileComparator: initialGoldenFileComparator,
        );
      });

      tearDown(() {
        goldenFileComparator = initialGoldenFileComparator;
      });

      _i13.main();
    },
    timeout: Timeout.factor(1.5),
  );
  group(
    'timeout_04_test.dart',
    () {
      late GoldenFileComparator initialGoldenFileComparator;

      setUp(() {
        initialGoldenFileComparator = goldenFileComparator;
        goldenFileComparator = _DelegatingGoldenFileComparator(
          goldensDir: Directory('.'),
          delegateGoldenFileComparator: initialGoldenFileComparator,
        );
      });

      tearDown(() {
        goldenFileComparator = initialGoldenFileComparator;
      });

      _i14.main();
    },
    timeout: Timeout.none,
  );
}

final class _DelegatingGoldenFileComparator extends GoldenFileComparator {
  _DelegatingGoldenFileComparator({
    required this.goldensDir,
    required this.delegateGoldenFileComparator,
  });

  final Directory goldensDir;
  final GoldenFileComparator delegateGoldenFileComparator;

  Uri prependGoldenUri(Uri goldenUri) {
    return goldenUri.replace(
      path: p.join(
        goldensDir.path,
        goldenUri.path,
      ),
    );
  }

  @override
  Future<bool> compare(
    Uint8List imageBytes,
    Uri goldenUri,
  ) {
    // Workaround required for web tests,
    // as they do not use `getTestUri`.
    final resolvedGoldenUri = isBrowser
        ? prependGoldenUri(goldenUri)
        : goldenUri;
    return delegateGoldenFileComparator.compare(
      imageBytes,
      resolvedGoldenUri,
    );
  }

  @override
  Future<void> update(
    Uri goldenUri,
    Uint8List imageBytes,
  ) {
    return delegateGoldenFileComparator.update(
      goldenUri,
      imageBytes,
    );
  }

  @override
  Uri getTestUri(
    Uri key,
    int? version,
  ) {
    final delegateKey = delegateGoldenFileComparator.getTestUri(key, version);
    final resolvedKey = prependGoldenUri(delegateKey);
    return resolvedKey;
  }
}
''');
        expect(
          optimizedTestFile.existsSync(),
          isTrue,
          reason: 'optimized test '
              'should exist '
              'for $projectType flutter project',
        );
        expect(
          optimizedTestFile.readAsStringSync(),
          expectedOutput,
          reason: 'optimized test '
              'should preserve annotations and '
              'add golden tests setup '
              'for $projectType flutter project',
        );
      }
    });
  });
}

extension on String {
  bool get hasEmptyMainFunction {
    final result = parseString(
      content: this,
    );
    final unit = result.unit;
    final declarations = unit.declarations;
    final functionDeclarations = declarations.whereType<FunctionDeclaration>();
    final mainFunctionDeclaration = functionDeclarations
        .firstWhereOrNull((declaration) => declaration.name.lexeme == 'main');
    if (mainFunctionDeclaration == null) {
      throw Exception('Main function not found');
    }
    final mainFunctionBody = mainFunctionDeclaration.functionExpression.body;
    if (mainFunctionBody is! BlockFunctionBody) {
      throw Exception('Main function body is not a block function body');
    }
    return mainFunctionBody.block.statements.isEmpty;
  }
}
