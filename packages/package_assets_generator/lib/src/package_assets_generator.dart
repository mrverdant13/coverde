import 'package:build/build.dart';
import 'package:path/path.dart' show posix;

final path = posix;

class PackageAssetsBuilder implements Builder {
  static const inputDir = 'assets';
  static const outputDir = 'lib/src/assets';
  static const filePathPlaceholder = '{{}}';
  static const outputExtension = '.asset.dart';

  static final input = path.joinAll([
    inputDir,
    filePathPlaceholder,
  ]);
  static final output = path.joinAll([
    outputDir,
    '$filePathPlaceholder$outputExtension',
  ]);

  @override
  final buildExtensions = {
    input: [output],
  };

  static const _plainTextFileExtensions = ['.html', '.css'];

  @override
  Future<void> build(BuildStep buildStep) async {
    final origin = buildStep.inputId;
    final assetFilename = path.basename(origin.path);
    final assetContent = await buildStep.readAsBytes(origin);

    final sb = StringBuffer()
      ..writeln('// ! GENERATED CODE - DO NOT MODIFY BY HAND !')
      ..writeln()
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
        outputDir,
        path.relative(origin.path, from: inputDir),
      ),
    ).addExtension(outputExtension);

    await buildStep.writeAsString(destination, sb.toString());
  }
}

extension on String {
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

  String upperCaseFirstLetter(String word) {
    final firstLetter = word[0];
    final rest = word.substring(1);
    return '${firstLetter.toUpperCase()}${rest.toLowerCase()}';
  }

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

Builder packageAssetsBuilder(BuilderOptions options) => PackageAssetsBuilder();
