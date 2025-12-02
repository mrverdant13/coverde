import 'dart:async';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:code_builder/code_builder.dart' as coder;
import 'package:collection/collection.dart';
import 'package:coverde/src/commands/commands.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:universal_io/io.dart';

/// {@template optimize_tests_cmd}
/// A subcommand to optimize tests.
/// {@endtemplate}
class OptimizeTestsCommand extends CoverdeCommand {
  /// {@macro optimize_tests_cmd}
  OptimizeTestsCommand() {
    argParser
      ..addOption(
        includeOptionName,
        help: 'The glob pattern for the tests files to include.',
        defaultsTo: 'test/**_test.dart',
      )
      ..addOption(
        excludeOptionName,
        help: 'The glob pattern for the tests files to exclude.',
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

  /// The name of the option for the glob pattern for the tests files to
  /// include.
  static const includeOptionName = 'include';

  /// The name of the option for the glob pattern for the tests files to
  /// exclude.
  static const excludeOptionName = 'exclude';

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
    if (p.basenameWithoutExtension(outputPath).startsWith('.')) {
      logger.warn(
        'Beware that test files starting with a dot may cause issues '
        'when running them on web platforms.',
      );
    }
    final outputFile = File(p.join(projectDir.path, outputPath));
    if (outputFile.existsSync()) outputFile.deleteSync();
    final includeGlob = () {
      final pattern = argResults.option(includeOptionName)!.withoutQuotes;
      return Glob(pattern, context: p.posix);
    }();
    final excludeGlob = () {
      final pattern = argResults.option(excludeOptionName)?.withoutQuotes;
      if (pattern == null) return null;
      return Glob(pattern, context: p.posix);
    }();

    final isFlutterPackage = switch (pubspec.dependencies['flutter']) {
          final SdkDependency dep => dep.sdk == 'flutter',
          _ => false,
        } ||
        switch (pubspec.devDependencies['flutter_test']) {
          final SdkDependency dep => dep.sdk == 'flutter',
          _ => false,
        };
    final useFlutterGoldenTests =
        argResults.flag(useFlutterGoldenTestsFlagName) && isFlutterPackage;

    final fileRelativePaths = projectDir
        .listSync(recursive: true)
        .whereType<File>()
        .sortedBy((it) => it.path)
        .map((it) {
      final filePath = p.posix.joinAll(
        p.split(
          p.relative(
            it.path,
            from: projectDir.path,
          ),
        ),
      );
      return filePath;
    });

    final includedFileRelativePaths =
        fileRelativePaths.where(includeGlob.matches);
    final validFileRelativePaths = switch (excludeGlob) {
      null => includedFileRelativePaths,
      _ => includedFileRelativePaths.whereNot(excludeGlob.matches),
    };

    final testFileGroupsStatements = <coder.Code>[];
    var hasAsyncEntryPoints = false;
    for (final fileRelativePath in validFileRelativePaths) {
      final fileContent = File(fileRelativePath).absolute.readAsStringSync();
      final result = parseString(
        content: fileContent,
        featureSet: FeatureSet.latestLanguageVersion(),
      );
      final unit = result.unit;
      final declarations = unit.declarations;
      final functionDeclarations =
          declarations.whereType<FunctionDeclaration>();
      final mainFunctionDeclaration = functionDeclarations.firstWhereOrNull(
        (declaration) => declaration.name.lexeme == 'main',
      );
      if (mainFunctionDeclaration == null) {
        logger.warn(
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
        logger.warn(
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
      final testRelativePath = p.posix.joinAll(
        p.split(
          p.relative(
            fileRelativePath,
            from: outputFile.parent.path,
          ),
        ),
      );
      final testInvocation = () {
        final expression = mainFunctionDeclaration.functionExpression;
        final mainFunctionIsAsync = () {
          if (expression.body.isAsynchronous) return true;
          final returnType = mainFunctionDeclaration.returnType;
          if (returnType is! NamedType) return false;
          return returnType.name.lexeme == 'Future';
        }();
        hasAsyncEntryPoints |= mainFunctionIsAsync;
        final setUpInvocation = () {
          if (!useFlutterGoldenTests) return null;
          return coder.Code(
            '''
late GoldenFileComparator initialGoldenFileComparator;

setUp(() {
  initialGoldenFileComparator = goldenFileComparator;
  goldenFileComparator = _DelegatingGoldenFileComparator(
    goldensDir: Directory(${coder.literalString(p.dirname(testRelativePath))}),
    delegateGoldenFileComparator: initialGoldenFileComparator,
  );
});

tearDown(() {
  goldenFileComparator = initialGoldenFileComparator;
});
''',
          );
        }();
        final mainInvocation = () {
          final mainFunction = coder.Reference('main', testRelativePath);
          if (!mainFunctionIsAsync) return mainFunction.call([]);
          logger.warn(
            'Test file $fileRelativePath has an async `main` function.',
          );
          return const coder.Reference('unawaited').call([
            const coder.Reference('Future.sync').call([
              mainFunction,
            ]),
          ]);
        }();
        return coder.Method(
          (b) => b
            ..body = coder.Block.of([
              if (setUpInvocation != null) setUpInvocation,
              mainInvocation.statement,
            ]),
        ).closure;
      }();
      final testFileGroupStatement = const coder.Reference('group').call(
        [
          coder.literalString(testRelativePath),
          testInvocation,
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
    final mainFunction = coder.Method.returnsVoid(
      (b) => b
        ..name = 'main'
        ..body = coder.Block.of([
          ...testFileGroupsStatements,
        ]),
    );
    final library = coder.Library(
      (b) {
        if (testFileGroupsStatements.isNotEmpty) {
          b.directives.addAll([
            coder.Directive.import('package:test_api/test_api.dart'),
            if (hasAsyncEntryPoints)
              coder.Directive.import(
                'dart:async',
                show: const ['unawaited'],
              ),
            if (useFlutterGoldenTests) ...[
              coder.Directive.import(
                'dart:io',
              ),
              coder.Directive.import(
                'dart:typed_data',
              ),
              coder.Directive.import(
                'package:flutter_test/flutter_test.dart',
                hide: const ['group', 'setUp', 'tearDown'],
              ),
              coder.Directive.import(
                'package:path/path.dart',
                as: 'p',
              ),
            ],
          ]);
        }
        b
          ..ignoreForFile.addAll([
            'type=lint',
            if (testFileGroupsStatements.isNotEmpty) 'deprecated_member_use',
          ])
          ..body.addAll([
            mainFunction,
            if (testFileGroupsStatements.isNotEmpty && useFlutterGoldenTests)
              const coder.Code(_goldenFileComparatorClassDefinition),
          ]);
      },
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

const _goldenFileComparatorClassDefinition = '''
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
''';

extension on String {
  String get withoutQuotes {
    if (length < 2) return this;
    if ((startsWith('"') && endsWith('"')) ||
        (startsWith("'") && endsWith("'"))) {
      return substring(1, length - 1);
    }
    return this;
  }
}
