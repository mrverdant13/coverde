import 'dart:async';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart' as coder;
import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';
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
        help: 'The regex pattern to filter the tests files.',
        defaultsTo: 'test/.*_test.dart',
      )
      ..addOption(
        outputOptionName,
        help: 'The path to the optimized tests file.',
        defaultsTo: 'test/optimized_test.dart',
      )
      ..addFlag(
        useFlutterGoldenTestsFlagName,
        help: 'Whether to use golden tests in case of a Flutter package.',
        defaultsTo: true,
      );
  }

  @override
  bool get takesArguments => false;

  @override
  String get description => 'Optimize tests by gathering them.';

  @override
  String get name => 'optimize-tests';

  /// The name of the option for the regex pattern to filter the tests files.
  static const filterOptionName = 'filter';

  /// The name of the flag for the use of golden tests in case of a Flutter
  /// package.
  static const useFlutterGoldenTestsFlagName = 'flutter-goldens';

  /// The name of the option for the generated optimized tests file.
  static const outputOptionName = 'output';

  /// The regex to match the onPlatform annotation.
  static final onPlatformRegex = RegExp(
    r'^@OnPlatform\((?<onPlatform>[\s\S]*?)\)$',
    dotAll: true,
    multiLine: true,
  );

  /// The regex to match the skip annotation.
  static final skipRegex = RegExp(
    r'^@Skip\((?<skip>[\s\S]*?)\)$',
    dotAll: true,
    multiLine: true,
  );

  /// The regex to match the tags annotation.
  static final tagsRegex = RegExp(
    r'^@Tags\((?<tags>[\s\S]*?)\)$',
    dotAll: true,
    multiLine: true,
  );

  /// The regex to match the testOn annotation.
  static final testOnRegex = RegExp(
    r'^@TestOn\((?<testOn>[\s\S]*?)\)$',
    dotAll: true,
    multiLine: true,
  );

  /// The regex to match the timeout annotation.
  static final timeoutRegex = RegExp(
    r'^@(?<timeout>Timeout\([\s\S]*?\)|Timeout\.none|Timeout\.factor\((?:\d+\.?\d*|\d*\.\d+)\))$',
    dotAll: true,
    multiLine: true,
  );

  @override
  FutureOr<void> run() async {
    final argResults = this.argResults!;
    final projectDir = Directory.current;
    final pubspecFile = File(p.join(projectDir.path, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      usageException('pubspec.yaml not found in ${projectDir.path}.');
    }
    final pubspecRawContent = pubspecFile.readAsStringSync();
    final pubspec = Pubspec.parse(pubspecRawContent);
    final outputPath = argResults.option(outputOptionName)!;
    final outputFile = File(p.join(projectDir.path, outputPath));
    if (outputFile.existsSync()) outputFile.deleteSync(recursive: true);
    final rawFilter = argResults.option(filterOptionName)!;
    final filter = RegExp(rawFilter);
    final files = projectDir
        .listSync(recursive: true)
        .whereType<File>()
        .sortedBy((it) => it.path);

    final testFileGroupsStatements = <coder.Code>[];
    for (final file in files) {
      final fileRelativePath = p.relative(
        file.path,
        from: projectDir.path,
      );
      if (!filter.hasMatch(fileRelativePath)) continue;
      final fileContent = file.readAsStringSync();
      final result = parseFile(
        path: file.path,
        featureSet: FeatureSet.latestLanguageVersion(),
      );
      final unit = result.unit;
      final declarations = unit.declarations;
      final functionDeclarations =
          declarations.whereType<FunctionDeclaration>();
      final mainFunctionDeclaration = functionDeclarations
          .firstWhereOrNull((declaration) => declaration.name.lexeme == 'main');
      if (mainFunctionDeclaration == null) {
        stdout.writeln(
          'Test file $fileRelativePath does not have a `main` function.',
        );
        continue;
      }
      final mainFunctionHasParams =
          switch (mainFunctionDeclaration.functionExpression.parameters) {
        FormalParameterList(:final parameters) => parameters.isNotEmpty,
        null => false,
      };
      if (mainFunctionHasParams) {
        stdout.writeln(
          'Test file $fileRelativePath has a `main` function with params.',
        );
        continue;
      }
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
              skip == '' ? coder.literalBool(true).code : coder.Code(skip),
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
    final isFlutterPackage = switch (pubspec.dependencies['flutter']) {
      final SdkDependency dep => dep.sdk == 'flutter',
      _ => false,
    };
    final useFlutterGoldenTests =
        argResults.flag(useFlutterGoldenTestsFlagName) &&
            isFlutterPackage &&
            testFileGroupsStatements.isNotEmpty;
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
          if (useFlutterGoldenTests)
            coder.Directive.import(
              'package:flutter_test/flutter_test.dart',
              hide: const ['group'],
            ),
          if (testFileGroupsStatements.isNotEmpty)
            coder.Directive.import('package:test_api/test_api.dart'),
          if (useFlutterGoldenTests) ...[
            coder.Directive.import('dart:io'),
            coder.Directive.import('dart:typed_data'),
          ],
        ])
        ..ignoreForFile.addAll([
          'type=lint',
          if (testFileGroupsStatements.isNotEmpty) 'deprecated_member_use',
        ])
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
    final unformattedOutput = '${library.accept(emitter)}';
    final output = formatter.format(unformattedOutput);
    if (!outputFile.parent.existsSync()) {
      outputFile.parent.createSync(recursive: true);
    }
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
