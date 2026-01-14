import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:collection/collection.dart';
import 'package:coverde/src/commands/commands.dart';
import 'package:coverde/src/entities/entities.dart';
import 'package:coverde/src/utils/utils.dart';
import 'package:dart_style/dart_style.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:universal_io/universal_io.dart';

import '../../../helpers/test_files.dart';

final class _MockLogger extends Mock implements Logger {}

final class _MockPackageVersionManager extends Mock
    implements PackageVersionManager {}

final class _FakeCoverdeCommandRunner extends CoverdeCommandRunner {
  _FakeCoverdeCommandRunner({
    required super.logger,
    required super.packageVersionManager,
  });

  @override
  Future<void> run(Iterable<String> args) {
    return super.run([
      ...args,
      '''--${CoverdeCommandRunner.updateCheckOptionName}=${UpdateCheckMode.disabled.identifier}''',
    ]);
  }
}

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
    late Logger logger;
    late PackageVersionManager packageVersionManager;
    late CoverdeCommandRunner cmdRunner;

    setUp(() {
      logger = _MockLogger();
      packageVersionManager = _MockPackageVersionManager();
      cmdRunner = _FakeCoverdeCommandRunner(
        logger: logger,
        packageVersionManager: packageVersionManager,
      );
    });

    tearDown(() {
      verifyNoMoreInteractions(logger);
    });

    test('| usage', () {
      final subject = cmdRunner.commands['optimize-tests']!.usage;
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
                'optimize-tests',
              ]);
          expect(
            action,
            throwsA(
              isA<CoverdeOptimizeTestsPubspecNotFoundFailure>().having(
                (e) => e.projectDirPath,
                'projectDirPath',
                p.join(currentDirectory.path, projectPath),
              ),
            ),
          );
        },
        getCurrentDirectory: () => Directory(
          p.join(currentDirectory.path, projectPath),
        ),
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
              'optimize-tests',
              '--${OptimizeTestsCommand.outputOptionName}=test/.optimized_test.dart',
            ]);
          },
          getCurrentDirectory: () => Directory(
            p.join(currentDirectory.path, projectPath),
          ),
        );

        verify(
          () => logger.warn(
            'Beware that test files starting with a dot may cause issues '
            'when running them on web platforms.',
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
              'optimize-tests',
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
              'optimize-tests',
            ]);
          },
          getCurrentDirectory: () => Directory(
            p.join(currentDirectory.path, projectPath),
          ),
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
            () => logger.warn(
              'Test file ${p.joinAll(testFilePath)} '
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
            () => logger.warn(
              'Test file ${p.joinAll(testFilePath)} '
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
              'optimize-tests',
              '--no-${OptimizeTestsCommand.useFlutterGoldenTestsFlagName}',
            ]);
          },
          getCurrentDirectory: () => Directory(
            p.join(currentDirectory.path, projectPath),
          ),
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
            () => logger.warn(
              'Test file ${p.joinAll(testFilePath)} '
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
              'optimize-tests',
              '--no-${OptimizeTestsCommand.useFlutterGoldenTestsFlagName}',
            ]);
          },
          getCurrentDirectory: () => Directory(
            p.join(currentDirectory.path, projectPath),
          ),
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
              'optimize-tests',
              '--${OptimizeTestsCommand.excludeOptionName}="**_01_test.dart"',
              '--no-${OptimizeTestsCommand.useFlutterGoldenTestsFlagName}',
            ]);
          },
          getCurrentDirectory: () => Directory(
            p.join(currentDirectory.path, projectPath),
          ),
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
              'optimize-tests',
              '--${OptimizeTestsCommand.useFlutterGoldenTestsFlagName}',
            ]);
          },
          getCurrentDirectory: () => Directory(
            p.join(currentDirectory.path, projectPath),
          ),
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

    test(
      '| throws $CoverdeOptimizeTestsFileReadFailure '
      'when pubspec.yaml read fails',
      () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-optimize-tests-test-');
        addTearDown(() => directory.delete(recursive: true));
        final pubspecFilePath = p.join(directory.path, 'pubspec.yaml');
        File(pubspecFilePath).createSync();

        await IOOverrides.runZoned(
          () async {
            Future<void> action() => cmdRunner.run([
                  'optimize-tests',
                ]);

            expect(
              action,
              throwsA(
                isA<CoverdeOptimizeTestsFileReadFailure>().having(
                  (e) => e.filePath,
                  'filePath',
                  pubspecFilePath,
                ),
              ),
            );
          },
          getCurrentDirectory: () => directory,
          createFile: (path) {
            if (p.basename(path) == 'pubspec.yaml') {
              return _OptimizeTestsTestFile(
                path: path,
                existsSync: () => true,
                readAsStringSync: () => throw FileSystemException(
                  'Fake file read error',
                  path,
                ),
              );
            }
            throw UnsupportedError(
              'This file $path should not be created in this test',
            );
          },
        );
      },
    );

    test(
      '| throws $CoverdeOptimizeTestsFileDeleteFailure '
      'when output file delete fails',
      () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-optimize-tests-test-');
        addTearDown(() => directory.delete(recursive: true));
        final pubspecFilePath = p.join(directory.path, 'pubspec.yaml');
        final pubspecFile = File(pubspecFilePath)
          ..createSync()
          ..writeAsStringSync('name: test');
        final outputFilePath = p.join(directory.path, 'output.dart');

        await IOOverrides.runZoned(
          () async {
            Future<void> action() => cmdRunner.run([
                  'optimize-tests',
                  '--${OptimizeTestsCommand.outputOptionName}',
                  outputFilePath,
                ]);

            expect(
              action,
              throwsA(
                isA<CoverdeOptimizeTestsFileDeleteFailure>().having(
                  (e) => e.filePath,
                  'filePath',
                  outputFilePath,
                ),
              ),
            );
          },
          getCurrentDirectory: () => directory,
          createFile: (path) {
            if (p.basename(path) == 'pubspec.yaml') {
              return pubspecFile;
            }
            if (p.basename(path) == 'output.dart') {
              return _OptimizeTestsTestFile(
                path: path,
                existsSync: () => true,
                deleteSync: ({bool recursive = false}) =>
                    throw FileSystemException(
                  'Fake file delete error',
                  path,
                ),
              );
            }
            return File(path);
          },
        );
      },
    );

    test(
      '| throws $CoverdeOptimizeTestsDirectoryListFailure '
      'when project directory list fails',
      () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-optimize-tests-test-');
        addTearDown(() => directory.delete(recursive: true));
        final pubspecFilePath = p.join(directory.path, 'pubspec.yaml');
        final pubspecFile = File(pubspecFilePath)
          ..createSync()
          ..writeAsStringSync('name: test');
        final outputFilePath = p.join(directory.path, 'output.dart');
        final outputFile = File(outputFilePath);

        await IOOverrides.runZoned(
          () async {
            Future<void> action() => cmdRunner.run([
                  'optimize-tests',
                  '--${OptimizeTestsCommand.outputOptionName}',
                  outputFilePath,
                ]);

            expect(
              action,
              throwsA(
                isA<CoverdeOptimizeTestsDirectoryListFailure>().having(
                  (e) => e.directoryPath,
                  'directoryPath',
                  directory.path,
                ),
              ),
            );
          },
          getCurrentDirectory: () => _OptimizeTestsTestDirectory(
            path: directory.path,
            listSync: ({
              bool recursive = false,
              bool followLinks = true,
            }) =>
                throw FileSystemException(
              'Fake directory list error',
              directory.path,
            ),
          ),
          createFile: (path) {
            if (p.basename(path) == 'pubspec.yaml') {
              return pubspecFile;
            }
            if (p.basename(path) == 'output.dart') {
              return outputFile;
            }
            throw UnsupportedError(
              'This file $path should not be created in this test',
            );
          },
        );
      },
    );

    test(
      '| throws $CoverdeOptimizeTestsFileReadFailure '
      'when test file read fails',
      () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-optimize-tests-test-');
        addTearDown(() => directory.delete(recursive: true));
        final pubspecFilePath = p.join(directory.path, 'pubspec.yaml');
        final pubspecFile = File(pubspecFilePath)
          ..createSync()
          ..writeAsStringSync('name: test');
        final outputFilePath = p.join(directory.path, 'output.dart');
        final outputFile = File(outputFilePath);
        final testFilePath = p.joinAll([
          directory.path,
          'test',
          'some_test.dart',
        ]);
        File(testFilePath)
          ..createSync(recursive: true)
          ..writeAsStringSync('void main() {}');

        await IOOverrides.runZoned(
          () async {
            Future<void> action() => cmdRunner.run([
                  'optimize-tests',
                  '--${OptimizeTestsCommand.outputOptionName}',
                  outputFilePath,
                ]);

            expect(
              action,
              throwsA(
                isA<CoverdeOptimizeTestsFileReadFailure>().having(
                  (e) => e.filePath,
                  'filePath',
                  testFilePath,
                ),
              ),
            );
          },
          getCurrentDirectory: () => directory,
          createFile: (path) {
            if (p.basename(path) == 'pubspec.yaml') {
              return pubspecFile;
            }
            if (p.basename(path) == 'output.dart') {
              return outputFile;
            }
            if (p.basename(path) == 'some_test.dart') {
              return _OptimizeTestsTestFile(
                path: path,
                readAsString: () async => throw FileSystemException(
                  'Fake file read error',
                  testFilePath,
                ),
              );
            }
            throw UnsupportedError(
              'This file $path should not be created in this test',
            );
          },
        );
      },
    );

    test(
      '| throws $CoverdeOptimizeTestsDirectoryCreateFailure '
      'when output directory create fails',
      () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-optimize-tests-test-');
        addTearDown(() => directory.delete(recursive: true));
        final pubspecFilePath = p.join(directory.path, 'pubspec.yaml');
        final pubspecFile = File(pubspecFilePath)
          ..createSync()
          ..writeAsStringSync('name: test');
        final outputFilePath = p.joinAll([
          directory.path,
          'output',
          'output.dart',
        ]);
        final outputFile = File(outputFilePath);

        await IOOverrides.runZoned(
          () async {
            Future<void> action() => cmdRunner.run([
                  'optimize-tests',
                  '--${OptimizeTestsCommand.outputOptionName}',
                  outputFilePath,
                ]);

            expect(
              action,
              throwsA(
                isA<CoverdeOptimizeTestsDirectoryCreateFailure>().having(
                  (e) => e.directoryPath,
                  'directoryPath',
                  p.joinAll([directory.path, 'output']),
                ),
              ),
            );
          },
          getCurrentDirectory: () => directory,
          createDirectory: (path) {
            if (p.basename(path) == 'output') {
              return _OptimizeTestsTestDirectory(
                path: path,
                existsSync: () => false,
                createSync: ({bool recursive = false}) {
                  throw FileSystemException(
                    'Fake directory create error',
                    path,
                  );
                },
              );
            }
            throw UnsupportedError(
              'This directory $path should not be created in this test',
            );
          },
          createFile: (path) {
            if (p.basename(path) == 'pubspec.yaml') {
              return pubspecFile;
            }
            if (p.basename(path) == 'output.dart') {
              return outputFile;
            }
            throw UnsupportedError(
              'This file $path should not be created in this test',
            );
          },
        );
      },
    );

    test(
      '| throws $CoverdeOptimizeTestsFileWriteFailure '
      'when output file write fails',
      () async {
        final directory =
            Directory.systemTemp.createTempSync('coverde-optimize-tests-test-');
        addTearDown(() => directory.delete(recursive: true));
        final pubspecFilePath = p.join(directory.path, 'pubspec.yaml');
        final pubspecFile = File(pubspecFilePath)
          ..createSync()
          ..writeAsStringSync('name: test');
        final outputDirectoryPath = p.join(directory.path, 'output');
        final outputDirectory = Directory(outputDirectoryPath)
          ..createSync(recursive: true);
        final outputFilePath = p.joinAll([
          outputDirectory.path,
          'output.dart',
        ]);

        await IOOverrides.runZoned(
          () async {
            Future<void> action() => cmdRunner.run([
                  'optimize-tests',
                  '--${OptimizeTestsCommand.outputOptionName}',
                  outputFilePath,
                ]);

            expect(
              action,
              throwsA(
                isA<CoverdeOptimizeTestsFileWriteFailure>().having(
                  (e) => e.filePath,
                  'filePath',
                  outputFilePath,
                ),
              ),
            );
          },
          getCurrentDirectory: () => directory,
          createFile: (path) {
            if (p.basename(path) == 'pubspec.yaml') {
              return pubspecFile;
            }
            if (p.basename(path) == 'output.dart') {
              return _OptimizeTestsTestFile(
                path: path,
                existsSync: () => false,
                writeAsStringSync: (
                  contents, {
                  mode = FileMode.write,
                  encoding = utf8,
                  flush = false,
                }) =>
                    throw FileSystemException(
                  'Fake file write error',
                  path,
                ),
              );
            }
            throw UnsupportedError(
              'This file $path should not be created in this test',
            );
          },
        );
      },
    );
  });
}

final class _OptimizeTestsTestFile extends Fake implements File {
  _OptimizeTestsTestFile({
    required this.path,
    bool Function()? existsSync,
    String Function()? readAsStringSync,
    Future<String> Function()? readAsString,
    void Function(
      String contents, {
      FileMode mode,
      Encoding encoding,
      bool flush,
    })? writeAsStringSync,
    void Function({bool recursive})? deleteSync,
  })  : _existsSync = existsSync,
        _readAsStringSync = readAsStringSync,
        _readAsString = readAsString,
        _writeAsStringSync = writeAsStringSync,
        _deleteSync = deleteSync;

  @override
  final String path;

  final bool Function()? _existsSync;

  final String Function()? _readAsStringSync;

  final Future<String> Function()? _readAsString;

  final void Function(
    String contents, {
    FileMode mode,
    Encoding encoding,
    bool flush,
  })? _writeAsStringSync;

  final void Function({bool recursive})? _deleteSync;

  @override
  File get absolute => File(p.absolute(path));

  @override
  Directory get parent {
    final [...parentSegments, _] = p.split(path);
    return Directory(p.joinAll(parentSegments));
  }

  @override
  bool existsSync() {
    if (_existsSync case final cb?) return cb();
    throw UnimplementedError();
  }

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    if (_readAsStringSync case final cb?) return cb();
    throw UnimplementedError();
  }

  @override
  Future<String> readAsString({Encoding encoding = utf8}) async {
    if (_readAsString case final cb?) return cb();
    throw UnimplementedError();
  }

  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    if (_writeAsStringSync case final cb?) {
      return cb(
        contents,
        mode: mode,
        encoding: encoding,
        flush: flush,
      );
    }
    throw UnimplementedError();
  }

  @override
  void deleteSync({bool recursive = false}) {
    if (_deleteSync case final cb?) return cb(recursive: recursive);
    throw UnimplementedError();
  }
}

final class _OptimizeTestsTestDirectory extends Fake implements Directory {
  _OptimizeTestsTestDirectory({
    required this.path,
    bool Function()? existsSync,
    void Function({bool recursive})? createSync,
    List<FileSystemEntity> Function({
      bool recursive,
      bool followLinks,
    })? listSync,
  })  : _existsSync = existsSync,
        _createSync = createSync,
        _listSync = listSync;

  @override
  final String path;

  final bool Function()? _existsSync;

  final void Function({bool recursive})? _createSync;

  final List<FileSystemEntity> Function({
    bool recursive,
    bool followLinks,
  })? _listSync;

  @override
  bool existsSync() {
    if (_existsSync case final cb?) return cb();
    throw UnimplementedError();
  }

  @override
  void createSync({bool recursive = false}) {
    if (_createSync case final cb?) return cb(recursive: recursive);
    throw UnimplementedError();
  }

  @override
  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) {
    if (_listSync case final cb?) {
      return cb(
        recursive: recursive,
        followLinks: followLinks,
      );
    }
    throw UnimplementedError();
  }
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
