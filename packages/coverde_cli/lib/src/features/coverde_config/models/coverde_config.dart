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
    this.coverageThresholds = const {},
  });

  /// Creates a [CoverdeConfig] from a YAML string.
  ///
  /// [baseDirectory] is the directory of the file [yamlString] came from.
  /// A relative `file` on a `preset` step is stored against it.
  /// It defaults to the current working directory.
  ///
  /// Throws [CoverdeConfigFromYamlFailure] when an error occurs.
  factory CoverdeConfig.fromYaml(String yamlString, {String? baseDirectory}) {
    return _parseCoverdeConfigFromYaml(
      yamlString,
      baseDirectory: baseDirectory ?? Directory.current.path,
    );
  }

  /// The [PresetTransformation]s that are available to use in the CLI.
  final List<PresetTransformation> presets;

  /// Named coverage thresholds from the `coverage` map.
  ///
  /// Each value is a percentage in the inclusive range 0-100.
  final Map<String, double> coverageThresholds;

  /// Equality for [presets].
  static const _presetsEquality = ListEquality<PresetTransformation>();

  /// Equality for [coverageThresholds].
  static const _coverageThresholdsEquality = MapEquality<String, double>();

  @override
  bool operator ==(Object other) {
    if (other is! CoverdeConfig) return false;
    return _presetsEquality.equals(presets, other.presets) &&
        _coverageThresholdsEquality.equals(
          coverageThresholds,
          other.coverageThresholds,
        );
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    _presetsEquality.hash(presets),
    _coverageThresholdsEquality.hash(coverageThresholds),
  ]);
}
