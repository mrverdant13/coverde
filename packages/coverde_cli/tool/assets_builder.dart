import 'package:build/build.dart';
import 'package:coverde/src/utils/path.dart';

class AssetsBuilder implements Builder {
  static const _inputDirSegments = ['assets'];
  static final _inputDir = _inputDirSegments.reduce(path.join);

  static const _outputDirSegments = ['lib', 'src', 'assets'];
  static final _outputDir = _outputDirSegments.reduce(path.join);

  static const _outputExtension = '.asset.dart';

  static final _inputPath = '$_inputDir/{{}}';
  static final _outputPath = '$_outputDir/{{}}$_outputExtension';

  @override
  final buildExtensions = {
    _inputPath: [_outputPath],
  };

  static const _plainTextFileExtensions = ['.html', '.css'];

  @override
  Future<void> build(BuildStep buildStep) async {
    final origin = buildStep.inputId;
    final assetFilename = path.basename(origin.path);
    final assetContent = await buildStep.readAsBytes(origin);

    final sb = StringBuffer()
      ..writeln('/// The filename of the')
      ..writeln('/// `$assetFilename` asset')
      ..writeln("const ${assetFilename.asCamelCase}Filename = '''")
      ..write(assetFilename)
      ..writeln("''';")
      ..writeln()
      ..writeln('/// The collection of bytes that represent the content of the')
      ..writeln('/// `$assetFilename` asset.')
      ..writeln('const ${assetFilename.asCamelCase}Bytes = <int>[');
    for (final b in assetContent) {
      final isPlainTextFile = _plainTextFileExtensions.contains(
        origin.extension,
      );
      // Ignore `CR` char for plain text files.
      // This avoids issues related to platform specific line endings.
      if (b != 13 || !isPlainTextFile) {
        sb.writeln('  $b,');
      }
    }
    sb.writeln('];');

    final destination = AssetId(
      origin.package,
      path.join(
        _outputDir,
        path.relative(origin.path, from: _inputDir),
      ),
    ).addExtension(_outputExtension);

    await buildStep.writeAsString(destination, sb.toString());
  }
}

extension ExtendedString on String {
  static const symbolSet = {' ', '.', '/', '_', r'\', '-'};
  static final upperAlphaRegex = RegExp('[A-Z]');

  List<String> get words {
    final sb = StringBuffer();
    final words = <String>[];
    final isAllCaps = toUpperCase() == this;

    for (var i = 0; i < length; i++) {
      final char = this[i];
      final nextChar = i + 1 == length ? null : this[i + 1];

      if (symbolSet.contains(char)) {
        continue;
      }

      sb.write(char);

      final isEndOfWord = nextChar == null ||
          (upperAlphaRegex.hasMatch(nextChar) && !isAllCaps) ||
          symbolSet.contains(nextChar);

      if (isEndOfWord) {
        words.add(sb.toString());
        sb.clear();
      }
    }

    return words;
  }

  String upperCaseFirstLetter(String word) =>
      '${word.substring(0, 1).toUpperCase()}${word.substring(1).toLowerCase()}';

  String get asCamelCase {
    if (words.isEmpty) return this;
    final firstWord = words.first;
    final pascalCase = [
      firstWord.toLowerCase(),
      ...words.skip(1).map(upperCaseFirstLetter),
    ].join();
    return pascalCase;
  }
}

Builder assetsBuilder(BuilderOptions options) => AssetsBuilder();
