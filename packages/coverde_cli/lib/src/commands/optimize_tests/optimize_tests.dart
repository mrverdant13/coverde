import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart' as coder;
import 'package:collection/collection.dart';
import 'package:coverde/src/utils/command.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:universal_io/io.dart';

/// {@template optimize_tests_cmd}
/// A subcommand to optimize tests.
/// {@endtemplate}
class OptimizeTestsCommand extends Command<void> {
  /// {@macro optimize_tests_cmd}
  OptimizeTestsCommand() {
    argParser
      ..addOption(
        filterOptionName,
        help: 'The glob pattern to filter the tests files.',
        defaultsTo: 'test/**/*_test.dart',
      )
      ..addOption(
        outputOptionName,
        help: 'The path to the optimized tests file.',
        defaultsTo: 'optimized_test.dart',
      )
      ..addFlag(
        useFlutterGoldenTestsFlagName,
        help: 'Whether to use golden tests in case of a Flutter package.',
        defaultsTo: true,
      );
  }

  @override
  String get description => 'Optimize tests by gathering them.';

  @override
  String get name => 'optimize-tests';

  /// The name of the option for the glob pattern to filter the tests files.
  static const filterOptionName = 'filter';

  /// The name of the flag for the use of golden tests in case of a Flutter
  /// package.
  static const useFlutterGoldenTestsFlagName = 'flutter-goldens';

  /// The name of the option for the generated optimized tests file.
  static const outputOptionName = 'output';

  /// The regex to match the onPlatform annotation.
  static final onPlatformRegex = RegExp(
    r'@OnPlatform\((?<onPlatform>[\s\S]*?)\)',
    dotAll: true,
  );

  /// The regex to match the skip annotation.
  static final skipRegex = RegExp(
    r'@Skip\((?<skip>[\s\S]*?)\)',
    dotAll: true,
  );

  /// The regex to match the tags annotation.
  static final tagsRegex = RegExp(
    r'@Tags\((?<tags>[\s\S]*?)\)',
    dotAll: true,
  );

  /// The regex to match the testOn annotation.
  static final testOnRegex = RegExp(
    r'@TestOn\((?<testOn>[\s\S]*?)\)',
    dotAll: true,
  );

  /// The regex to match the timeout annotation.
  static final timeoutRegex = RegExp(
    r'@(?<timeout>Timeout\([\s\S]*?\))',
    dotAll: true,
  );

  @override
  FutureOr<void>? run() async {
    final projectDir = Directory.current;
    final pubspecFile = File(p.join(projectDir.path, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      // TODO(mrverdant13): Use custom exceptions.
      throw Exception('pubspec.yaml not found in ${projectDir.path}');
    }

    final pubspecRawContent = pubspecFile.readAsStringSync();
    final pubspec = Pubspec.parse(pubspecRawContent);
    final isFlutterPackage = pubspec.flutter != null;
    final useFlutterGoldenTests = checkFlag(
          flagKey: useFlutterGoldenTestsFlagName,
          flagName: 'Flutter golden tests',
        ) &&
        isFlutterPackage;

    final outputPath = checkOption(
      optionKey: outputOptionName,
      optionName: 'output path',
    );
    final outputFile = File(outputPath);
    if (outputFile.existsSync()) {
      outputFile.deleteSync(recursive: true);
    }

    final rawFilter = checkOption(
      optionKey: filterOptionName,
      optionName: 'glob pattern',
    );
    final filter = Glob(rawFilter);
    final testFileGroupsStatements = <coder.Code>[];
    final files = filter.listSync().whereType<File>().sortedBy((it) => it.path);
    for (final file in files) {
      final fileContent = file.readAsStringSync();
      final onPlatform =
          onPlatformRegex.firstMatch(fileContent)?.namedGroup('onPlatform');
      final skip = skipRegex.firstMatch(fileContent)?.namedGroup('skip');
      final tags = tagsRegex.firstMatch(fileContent)?.namedGroup('tags');
      final testOn = testOnRegex.firstMatch(fileContent)?.namedGroup('testOn');
      final timeout =
          timeoutRegex.firstMatch(fileContent)?.namedGroup('timeout');
      final testRelativePath = p.relative(
        file.path,
        from: outputFile.parent.path,
      );
      final mainFunction = coder.Reference('main', testRelativePath);
      final testFileGroupStatement = const coder.Reference('group').call(
        [
          coder.literalString(testRelativePath),
          mainFunction,
        ],
        {
          if (onPlatform != null)
            'onPlatform': coder.CodeExpression(
              coder.Code(onPlatform),
            ),
          if (skip != null)
            'skip': coder.CodeExpression(
              coder.Code(skip),
            ),
          if (tags != null)
            'tags': coder.CodeExpression(
              coder.Code(tags),
            ),
          if (testOn != null)
            'testOn': coder.CodeExpression(
              coder.Code(testOn),
            ),
          if (timeout != null)
            'timeout': coder.CodeExpression(
              coder.Code(timeout),
            ),
        },
      ).statement;
      testFileGroupsStatements.add(testFileGroupStatement);
    }

    final mainFunction = coder.Method.returnsVoid(
      (b) => b
        ..name = 'main'
        ..body = coder.Block.of([
          if (useFlutterGoldenTests) const coder.Code(_setUpStatement),
          ...testFileGroupsStatements,
        ]),
    );
    final library = coder.Library(
      (b) => b
        ..directives.addAll([
          coder.Directive.import(
            // TODO(mrverdant13): Check actual dependencies.
            isFlutterPackage
                ? 'package:flutter_test/flutter_test.dart'
                : 'package:test/test.dart',
          ),
          if (useFlutterGoldenTests) ...[
            coder.Directive.import('dart:io'),
            coder.Directive.import('dart:typed_data'),
          ],
        ])
        ..ignoreForFile.add('type=lint')
        ..body.addAll([
          mainFunction,
          if (useFlutterGoldenTests)
            const coder.Code(_goldenFileComparatorClassDefinition),
        ]),
    );
    final emitter = coder.DartEmitter.scoped(
      orderDirectives: true,
      useNullSafetySyntax: true,
    );
    final formatter = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
      trailingCommas: TrailingCommas.preserve,
    );
    final output = formatter.format('${library.accept(emitter)}');
    outputFile.writeAsStringSync(output);
  }
}

const _setUpStatement = '''
setUp(() {
  goldenFileComparator = _TestOptimizationAwareGoldenFileComparator(
    goldenFilePaths: _goldenFilePaths,
    testOptimizationUnawareGoldenFileComparator: goldenFileComparator,
  );
});
''';

const _goldenFileComparatorClassDefinition = '''
final class _TestOptimizationAwareGoldenFileComparator
    extends GoldenFileComparator {
  _TestOptimizationAwareGoldenFileComparator({
    required this.goldenFilePaths,
    required this.testOptimizationUnawareGoldenFileComparator,
  });

  final Iterable<String> goldenFilePaths;
  final GoldenFileComparator testOptimizationUnawareGoldenFileComparator;

  @override
  Future<bool> compare(
    Uint8List imageBytes,
    Uri goldenUri,
  ) => testOptimizationUnawareGoldenFileComparator.compare(
    imageBytes,
    goldenUri,
  );

  @override
  Future<void> update(
    Uri goldenUri,
    Uint8List imageBytes,
  ) => testOptimizationUnawareGoldenFileComparator.update(
    goldenUri,
    imageBytes,
  );

  @override
  Uri getTestUri(
    Uri key,
    int? version,
  ) {
    final keyString = key.toFilePath();
    final goldenFilePath = goldenFilePaths.singleWhere(
      (it) => it.endsWith(keyString),
    );
    return Uri.parse(goldenFilePath);
  }
}

Iterable<String> get _goldenFilePaths sync* {
  final comparator = goldenFileComparator;
  if (comparator is! LocalFileComparator) return;
  yield* Directory.fromUri(comparator.basedir)
      .listSync(
        recursive: true,
        followLinks: true,
      )
      .whereType<File>()
      .map((it) => it.path)
      .where((it) => it.endsWith('.png'));
}
''';
