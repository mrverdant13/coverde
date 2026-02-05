part of 'coverde_config.dart';

/// {@template coverde.coverde_config_from_yaml_failure}
/// A failure that occurs when a [CoverdeConfig] is not valid YAML.
/// {@endtemplate}
@immutable
sealed class CoverdeConfigFromYamlFailure implements Exception {
  /// {@macro coverde.coverde_config_from_yaml_failure}
  const CoverdeConfigFromYamlFailure();
}

/// {@template coverde.coverde_config_from_yaml_invalid_yaml_failure}
/// A failure that occurs when the YAML string is invalid.
/// {@endtemplate}
@immutable
final class CoverdeConfigFromYamlInvalidYamlFailure
    extends CoverdeConfigFromYamlFailure {
  /// {@macro coverde.coverde_config_from_yaml_invalid_yaml_failure}
  const CoverdeConfigFromYamlInvalidYamlFailure({
    required this.yamlString,
    required this.yamlException,
  });

  /// The YAML string.
  final String yamlString;

  /// The YAML exception.
  final yaml.YamlException yamlException;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde.coverde_config_from_yaml_invalid_yaml_member_type_failure}
/// A failure that occurs when the YAML member is not of the expected type.
/// {@endtemplate}
@immutable
final class CoverdeConfigFromYamlInvalidYamlMemberTypeFailure
    extends CoverdeConfigFromYamlFailure {
  /// {@macro coverde.coverde_config_from_yaml_invalid_yaml_member_type_failure}
  const CoverdeConfigFromYamlInvalidYamlMemberTypeFailure({
    required this.key,
    required this.expectedType,
    required this.value,
  });

  /// The key of the member with the invalid type.
  ///
  /// If `null`, the invalid member is the root member.
  final String? key;

  /// The expected type of the member with the invalid type.
  final Type expectedType;

  /// The value of the member with the invalid type.
  final dynamic value;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde.coverde_config_from_yaml_invalid_yaml_member_value_failure}
/// A failure that occurs when the YAML member value is invalid.
/// {@endtemplate}
@immutable
final class CoverdeConfigFromYamlInvalidYamlMemberValueFailure
    extends CoverdeConfigFromYamlFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde.coverde_config_from_yaml_invalid_yaml_member_value_failure}
  const CoverdeConfigFromYamlInvalidYamlMemberValueFailure({
    required this.key,
    required this.value,
    this.hint,
  });

  /// The key of the member with the invalid value.
  ///
  /// If `null`, the invalid member is the root member.
  final String? key;

  /// The value of the member with the invalid value.
  final dynamic value;

  /// A hint to identify the invalid value.
  final String? hint;
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde.coverde_config_from_yaml_invalid_coverage_percentage_failure}
/// A failure that occurs when a coverage percentage value is out of the valid
/// range (0-100).
/// {@endtemplate}
@immutable
final class CoverdeConfigFromYamlInvalidCoveragePercentageFailure
    extends CoverdeConfigFromYamlFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde.coverde_config_from_yaml_invalid_coverage_percentage_failure}
  const CoverdeConfigFromYamlInvalidCoveragePercentageFailure({
    required this.key,
    required this.invalidReferences,
  });

  /// The key of the member with the invalid value.
  final String key;

  /// The coverage reference values that are out of range.
  final List<double> invalidReferences;
}

/// {@template coverde.coverde_config_from_yaml_unknown_preset_failure}
/// A failure that occurs when a preset is not found.
/// {@endtemplate}
@immutable
final class CoverdeConfigFromYamlUnknownPresetFailure
    extends CoverdeConfigFromYamlFailure {
  /// {@macro coverde.coverde_config_from_yaml_unknown_preset_failure}
  const CoverdeConfigFromYamlUnknownPresetFailure({
    required this.unknownPreset,
    required this.availablePresets,
  });

  /// The unknown preset name.
  final String unknownPreset;

  /// The available preset names.
  final List<String> availablePresets;
}

/// {@template coverde.coverde_config_from_yaml_preset_cycle_failure}
/// A failure that occurs when a preset cycle is detected.
/// {@endtemplate}
@immutable
final class CoverdeConfigFromYamlPresetCycleFailure
    extends CoverdeConfigFromYamlFailure {
  /// {@macro coverde.coverde_config_from_yaml_preset_cycle_failure}
  const CoverdeConfigFromYamlPresetCycleFailure({
    required this.cycle,
  });

  /// The preset cycle.
  final List<String> cycle;
}
