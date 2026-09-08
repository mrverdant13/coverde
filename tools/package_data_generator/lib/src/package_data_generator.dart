import 'package:build/build.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

class PackageDataBuilder implements Builder {
  PackageDataBuilder({
    required this.output,
  });

  static const input = 'pubspec.yaml';

  final String output;

  @override
  late final buildExtensions = {
    input: [output],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final origin = buildStep.inputId;
    final assetId = AssetId(buildStep.inputId.package, input);
    if (assetId != origin) return;
    final assetContent = await buildStep.readAsString(origin);
    final pubspec = Pubspec.parse(assetContent, sourceUrl: origin.uri);
    final version = pubspec.version;
    if (version == null) {
      throw Exception(
        'The `version` field is required in ${origin.path}.',
      );
    }
    final outputId = buildStep.allowedOutputs.single;
    await buildStep.writeAsString(
      outputId,
      generatePackageDataSource(
        packageName: pubspec.name,
        packageVersion: version.toString(),
      ),
    );
  }
}

Builder packageDataBuilder(BuilderOptions options) {
  const outputOptionKey = 'output';
  final output = options.config[outputOptionKey];
  if (output == null) {
    throw Exception('The `$outputOptionKey` option is required');
  }
  if (output is! String) {
    throw Exception('The `$outputOptionKey` option must be a string');
  }
  if (output.isEmpty) {
    throw Exception('The `$outputOptionKey` option is not valid');
  }
  return PackageDataBuilder(
    output: output,
  );
}

/// Generates the Dart source written by [PackageDataBuilder].
String generatePackageDataSource({
  required String packageName,
  required String packageVersion,
}) {
  return '''
// ! GENERATED CODE - DO NOT MODIFY BY HAND !

/// Package name.
const packageName = '$packageName';

/// Package version.
const packageVersion = '$packageVersion';
''';
}
