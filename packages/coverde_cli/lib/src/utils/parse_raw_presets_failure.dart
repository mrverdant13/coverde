part of 'presets_parser.dart';

/// {@template coverde.parse_raw_presets_failure}
/// A failure that occurs when parsing raw presets fails.
/// {@endtemplate}
sealed class ParseRawPresetsFailure implements Exception {
  /// {@macro coverde.parse_raw_presets_failure}
  const ParseRawPresetsFailure();
}

/// {@template coverde.parse_raw_presets_invalid_raw_presets_failure}
/// A failure that occurs when parsing raw presets fails.
/// {@endtemplate}
sealed class ParseRawPresetsInvalidRawPresetsFailure
    extends ParseRawPresetsFailure {
  /// {@macro coverde.parse_raw_presets_invalid_raw_presets_failure}
  const ParseRawPresetsInvalidRawPresetsFailure();
}

// Long doc template identifier.
// ignore: lines_longer_than_80_chars
/// {@template coverde.parse_raw_presets_invalid_raw_presets_member_type_failure}
/// A failure that occurs when parsing raw presets fails.
/// {@endtemplate}
final class ParseRawPresetsInvalidRawPresetsMemberTypeFailure
    extends ParseRawPresetsInvalidRawPresetsFailure {
  /// {@macro coverde.parse_raw_presets_invalid_raw_presets_member_type_failure}
  const ParseRawPresetsInvalidRawPresetsMemberTypeFailure({
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
