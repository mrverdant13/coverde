import 'package:collection/collection.dart';
import 'package:coverde/src/features/comparison/comparison.dart';
import 'package:coverde/src/features/transformations/transformations.dart';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:universal_io/io.dart';
import 'package:yaml/yaml.dart' as yaml;

part 'coverde_config_from_yaml.dart';
part 'coverde_config_from_yaml_failure.dart';

/// {@template coverde.coverde_config}
/// A configuration for the Coverde CLI.
/// {@endtemplate}
@immutable
class CoverdeConfig {
  /// {@macro coverde.coverde_config}
  const CoverdeConfig({
    required this.presets,
  });

  /// Creates a [CoverdeConfig] from a YAML string.
  ///
  /// [baseDirectory] is the directory of the file [yamlString] came from.
  /// A relative `file` on a `preset` step is stored against it.
  /// It defaults to the current working directory.
  ///
  /// Throws [CoverdeConfigFromYamlFailure] when an error occurs.
  factory CoverdeConfig.fromYaml(
    String yamlString, {
    String? baseDirectory,
  }) {
    return _parseCoverdeConfigFromYaml(
      yamlString,
      baseDirectory: baseDirectory ?? Directory.current.path,
    );
  }

  /// The [PresetTransformation]s that are available to use in the CLI.
  final List<PresetTransformation> presets;

  /// Equality for [presets].
  static const _presetsEquality = ListEquality<PresetTransformation>();

  @override
  bool operator ==(Object other) {
    if (other is! CoverdeConfig) return false;
    return _presetsEquality.equals(presets, other.presets);
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        _presetsEquality.hash(presets),
      ]);
}
