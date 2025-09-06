import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart' as coder;
import 'package:coverde/src/utils/command.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:universal_io/io.dart';

/// {@template test_cmd}
/// A subcommand to run tests performing a previous optimization step.
/// {@endtemplate}
class TestCommand extends Command<void> {
  /// {@macro test_cmd}
  TestCommand({Stdout? out, Stdout? err})
      : _out = out ?? stdout,
        _err = err ?? stderr {
    argParser.addOption(
      optimizedTestsFileNameOption,
      help: 'The name of the optimized tests file.',
      valueHelp: optimizedTestsFileNameHelpValue,
      defaultsTo: '.optimized_tests.dart',
    );
  }

  final Stdout _out;
  final Stdout _err;

  @override
  String get description =>
      'Run tests performing a previous optimization step.';

  @override
  String get name => 'test';

  static const optimizedTestsFileNameOption = 'optimized-tests-file-name';
  static const optimizedTestsFileNameHelpValue = 'OPTIMIZED_TESTS_FILE_NAME';

  static final onPlatformRegex = RegExp(r'@OnPlatform\((?<onPlatform>.*)\)');
  static final skipRegex = RegExp(r'@Skip\((?<skip>.*)\)');
  static final tagsRegex = RegExp(r'@Tags\((?<tags>.*)\)');
  static final testOnRegex = RegExp(r'@TestOn\((?<testOn>.*)\)');
  static final timeoutRegex = RegExp(r'@(?<timeout>Timeout\(.*\))');

  @override
  FutureOr<void>? run() async {
    try {
      final projectDir = Directory.current;
      final pubspecFile = File(p.join(projectDir.path, 'pubspec.yaml'));
      if (!pubspecFile.existsSync()) {
        // TODO(mrverdant13): Use custom exceptions.
        throw Exception('pubspec.yaml not found in ${projectDir.path}');
      }
      final testDir = Directory(p.join(projectDir.path, 'test'));
      if (!testDir.existsSync()) {
        // TODO(mrverdant13): Use custom exceptions.
        throw Exception('test directory not found in ${projectDir.path}');
      }

      final optimizedTestsFileName = checkOption(
        optionKey: optimizedTestsFileNameOption,
        optionName: 'optimized tests file name',
      );
      final optimizedTestsFilePath =
          p.join(testDir.path, optimizedTestsFileName);
      final optimizedTestsFile = File(optimizedTestsFilePath);

      const groupFunction = coder.Reference('group', 'package:test/test.dart');

      final filesStream = testDir.list(recursive: true);

      final testGroupDefinitions = <coder.Expression>[];
      await filesStream.forEach((file) {
        if (file is! File) return;
        if (!file.isTest) return;
        final fileContent = file.readAsStringSync();
        final onPlatform =
            onPlatformRegex.firstMatch(fileContent)?.namedGroup('onPlatform');
        final skip = skipRegex.firstMatch(fileContent)?.namedGroup('skip');
        final tags = tagsRegex.firstMatch(fileContent)?.namedGroup('tags');
        final testOn =
            testOnRegex.firstMatch(fileContent)?.namedGroup('testOn');
        final timeout =
            timeoutRegex.firstMatch(fileContent)?.namedGroup('timeout');
        final testRelativePath = p.relative(file.path, from: testDir.path);
        final mainFunction = coder.Reference('main', testRelativePath);
        final testGroupDefinition = groupFunction.call(
          [
            coder.literalString(testRelativePath, raw: true),
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
        );
        testGroupDefinitions.add(testGroupDefinition);
      });

      final library = coder.Library(
        (b) => b.body.addAll([
          coder.Method(
            (b) => b
              ..name = 'main'
              ..body = coder.Block((b) {
                for (final testGroupDefinition in testGroupDefinitions) {
                  b.statements.addAll([
                    testGroupDefinition.code,
                    const coder.Code(';'),
                  ]);
                }
              }),
          ),
        ]),
      );
      final emitter = coder.DartEmitter.scoped();
      final formatter = DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
      );
      final output = formatter.format('${library.accept(emitter)}');
      optimizedTestsFile.writeAsStringSync(output);

      final pubspecRawContent = pubspecFile.readAsStringSync();
      final pubspec = Pubspec.parse(pubspecRawContent);
      final isFlutterPackage = pubspec.flutter != null;

      final deferredCommandArguments = argResults?.rest;
      final process = await Process.start(
        isFlutterPackage ? 'flutter' : 'dart',
        [
          'test',
          optimizedTestsFilePath,
          ...?deferredCommandArguments,
        ],
      );
      await (
        process.exitCode,
        stdout.addStream(process.stdout),
        stderr.addStream(process.stderr),
      ).wait;
    } on Exception catch (e) {
      // TODO(mrverdant13): Use custom exceptions.
      _err.writeln(e);
    }
  }
}

extension on File {
  bool get isTest => path.endsWith('_test.dart');
}
