part of 'presets_parser.dart';

/// {@template coverde.expand_preset_failure}
/// Failure thrown when expanding a preset (e.g. unknown preset or cycle).
/// {@endtemplate}
sealed class ExpandPresetFailure implements Exception {
  /// {@macro coverde.expand_preset_failure}
  const ExpandPresetFailure();
}

/// {@template coverde.expand_preset_unknown_preset_failure}
/// Thrown when a referenced preset name is not defined.
/// {@endtemplate}
final class ExpandPresetUnknownPresetFailure extends ExpandPresetFailure {
  /// {@macro coverde.expand_preset_unknown_preset_failure}
  const ExpandPresetUnknownPresetFailure({
    required this.unknownPreset,
    required this.availablePresets,
  });

  /// The preset name that was referenced but not found.
  final String unknownPreset;

  /// The preset names that are defined (e.g. from config).
  final List<String> availablePresets;
}

/// {@template coverde.expand_preset_preset_cycle_failure}
/// Thrown when a cycle is detected in preset references.
/// {@endtemplate}
final class ExpandPresetPresetCycleFailure extends ExpandPresetFailure {
  /// {@macro coverde.expand_preset_preset_cycle_failure}
  const ExpandPresetPresetCycleFailure({required this.cycle});

  /// The preset cycle.
  final List<String> cycle;
}
