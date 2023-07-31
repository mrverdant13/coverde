import 'package:build/build.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

class CliDataBuilder implements Builder {
  static const _inputPath = 'pubspec.yaml';
  static const _outputPath = 'lib/src/utils/cli.data.dart';

  @override
  final buildExtensions = {
    _inputPath: [_outputPath],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final origin = buildStep.inputId;
    final assetContent = await buildStep.readAsString(origin);
    final pubspec = Pubspec.parse(assetContent);
    final cliName = pubspec.name;
    final cliVersion = pubspec.version;

    final sb = StringBuffer()
      ..writeln('/// The `coverde` CLI name.')
      ..writeln("const cliName = '$cliName';")
      ..writeln()
      ..writeln('/// The `coverde` CLI version.')
      ..writeln("const cliVersion = '$cliVersion';");

    final destination = AssetId(
      origin.package,
      _outputPath,
    );

    await buildStep.writeAsString(destination, sb.toString());
  }
}

Builder cliDataBuilder(BuilderOptions options) => CliDataBuilder();
