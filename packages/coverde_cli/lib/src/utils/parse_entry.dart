part of 'presets_parser.dart';

/// Private entry in a preset: either a concrete transformation or a reference
/// to another preset.
sealed class _PresetEntry {}

/// A preset step that is a concrete [Transformation].
final class _PresetEntryStep extends _PresetEntry {
  _PresetEntryStep(this.step);

  final Transformation step;
}

/// A preset step that references another preset by [name], which has not been
/// resolved yet.
final class _PresetEntryRef extends _PresetEntry {
  _PresetEntryRef(this.name);

  final String name;
}
