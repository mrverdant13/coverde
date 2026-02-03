part of 'presets_parser.dart';

/// {@template coverde.parse_preset_steps_failure}
/// A failure that occurs when parsing preset steps from config fails.
/// {@endtemplate}
sealed class ParsePresetStepsFailure implements Exception {
  /// {@macro coverde.parse_preset_steps_failure}
  const ParsePresetStepsFailure();
}

/// {@template coverde.parse_preset_steps_invalid_raw_preset_step_failure}
/// A failure that occurs when a raw preset step entry is invalid.
/// {@endtemplate}
sealed class ParsePresetStepsInvalidRawPresetStepFailure
    extends ParsePresetStepsFailure {
  /// {@macro coverde.parse_preset_steps_invalid_raw_preset_step_failure}
  const ParsePresetStepsInvalidRawPresetStepFailure();
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde.parse_preset_steps_invalid_raw_preset_step_member_type_failure}
/// A failure that occurs when a raw preset step member is not of the expected
/// type.
/// {@endtemplate}
final class ParsePresetStepsInvalidRawPresetStepMemberTypeFailure
    extends ParsePresetStepsInvalidRawPresetStepFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde.parse_preset_steps_invalid_raw_preset_step_member_type_failure}
  const ParsePresetStepsInvalidRawPresetStepMemberTypeFailure({
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
/// {@template coverde.parse_preset_steps_invalid_raw_preset_step_member_value_failure}
/// A failure that occurs when a raw preset step member value is invalid.
/// {@endtemplate}
final class ParsePresetStepsInvalidRawPresetStepMemberValueFailure
    extends ParsePresetStepsInvalidRawPresetStepFailure {
  // Long doc template identifier.
  // ignore: lines_longer_than_80_chars
  /// {@macro coverde.parse_preset_steps_invalid_raw_preset_step_member_value_failure}
  const ParsePresetStepsInvalidRawPresetStepMemberValueFailure({
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
