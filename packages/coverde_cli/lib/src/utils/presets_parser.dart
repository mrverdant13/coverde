import 'package:coverde/src/entities/entities.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart' as yaml;

part 'expand_preset_failure.dart';
part 'parse_entry.dart';
part 'parse_preset_steps_failure.dart';
part 'parse_raw_presets_failure.dart';

/// Parses and expands presets from coverde config (e.g. coverde.yaml).
///
/// Each preset is a list of steps that can be concrete transformations or
/// references to other presets.
class PresetsParser {
  /// Creates a [PresetsParser].
  PresetsParser();

  /// Parses presets from [rawConfig] and returns them as expanded
  /// [PresetTransformation]s.
  ///
  /// Throws:
  /// - [ParseRawPresetsFailure] in case of a presets group parsing issue.
  /// - [ParsePresetStepsFailure] in case of a preset steps parsing issue.
  /// - [ExpandPresetFailure] in case of a preset expansion issue.
  List<PresetTransformation> parsePresetsFromRawConfig(
    Map<String, dynamic> rawConfig,
  ) {
    final rawPresets = _parseRawPresets(rawConfig);
    if (rawPresets.isEmpty) return [];
    final result = <PresetTransformation>[];
    for (final name in rawPresets.keys) {
      result.add(
        PresetTransformation(
          presetName: name,
          steps: _expandPreset(
            presetName: name,
            presets: rawPresets,
            visiting: <String>{},
          ),
        ),
      );
    }
    return result;
  }

  /// Parses raw presets into a map of [_PresetEntry]s by their preset name.
  ///
  /// Throws:
  /// - [ParseRawPresetsFailure] in case of a presets group parsing issue.
  /// - [ParsePresetStepsFailure] in case of a preset steps parsing issue.
  Map<String, List<_PresetEntry>> _parseRawPresets(
    Map<String, dynamic> config,
  ) {
    final rawPresets = config['transformations'];
    if (rawPresets == null) return {};
    if (rawPresets is! Map) {
      throw ParseRawPresetsInvalidRawPresetsMemberTypeFailure(
        key: null,
        expectedType: Map<String, yaml.YamlMap>,
        value: rawPresets,
      );
    }
    final result = <String, List<_PresetEntry>>{};
    for (final MapEntry(key: presetName, value: rawSteps)
        in rawPresets.entries) {
      final presetKey = '[key=$presetName]';
      if (presetName is! String) {
        throw ParseRawPresetsInvalidRawPresetsMemberTypeFailure(
          key: presetKey,
          expectedType: MapEntry<String, yaml.YamlList>,
          value: presetName,
        );
      }
      if (rawSteps is! List) {
        throw ParseRawPresetsInvalidRawPresetsMemberTypeFailure(
          key: presetKey,
          expectedType: List<yaml.YamlMap>,
          value: rawSteps,
        );
      }
      result[presetName] = _parsePresetSteps(rawSteps, keyPrefix: presetKey);
    }
    return result;
  }

  /// Expands a preset into a list of [Transformation]s.
  ///
  /// Throws [ExpandPresetFailure].
  List<Transformation> _expandPreset({
    required String presetName,
    required Map<String, List<_PresetEntry>> presets,
    required Set<String> visiting,
  }) {
    final entries = presets[presetName];
    if (entries == null) {
      throw ExpandPresetUnknownPresetFailure(
        unknownPreset: presetName,
        availablePresets: presets.keys.toList()..sort(),
      );
    }
    if (visiting.contains(presetName)) {
      throw ExpandPresetPresetCycleFailure(
        cycle: [...visiting, presetName],
      );
    }
    visiting.add(presetName);
    final result = <Transformation>[];
    for (final entry in entries) {
      switch (entry) {
        case _PresetEntryStep(step: final step):
          result.add(step);
        case _PresetEntryRef(name: final name):
          result.add(
            PresetTransformation(
              presetName: name,
              steps: _expandPreset(
                presetName: name,
                presets: presets,
                visiting: visiting,
              ),
            ),
          );
      }
    }
    visiting.remove(presetName);
    return result;
  }

  /// Parses a list of preset steps into a list of [_PresetEntry]s.
  ///
  /// Throws [ParsePresetStepsFailure].
  List<_PresetEntry> _parsePresetSteps(
    List<dynamic> list, {
    required String keyPrefix,
  }) {
    if (list.isEmpty) return [];
    final result = <_PresetEntry>[];
    for (final (index, rawStep) in list.indexed) {
      final stepKey = [
        keyPrefix,
        '[$index]',
      ].join('.');
      if (rawStep is! Map) {
        throw ParsePresetStepsInvalidRawPresetStepMemberTypeFailure(
          key: stepKey,
          expectedType: Map,
          value: rawStep,
        );
      }
      final rawType = rawStep['type'];
      final stepTypeKey = [
        stepKey,
        'type',
      ].join('.');
      if (rawType is! String) {
        throw ParsePresetStepsInvalidRawPresetStepMemberTypeFailure(
          key: stepTypeKey,
          expectedType: String,
          value: rawType,
        );
      }
      switch (rawType) {
        case 'keep-by-regex':
          final rawRegex = rawStep['regex'];
          final regexKey = [
            stepKey,
            'regex',
          ].join('.');
          if (rawRegex is! String) {
            throw ParsePresetStepsInvalidRawPresetStepMemberTypeFailure(
              key: regexKey,
              expectedType: String,
              value: rawRegex,
            );
          }
          final RegExp regex;
          try {
            regex = RegExp(rawRegex);
          } on Object catch (_, stackTrace) {
            Error.throwWithStackTrace(
              ParsePresetStepsInvalidRawPresetStepMemberValueFailure(
                key: regexKey,
                value: rawRegex,
                hint: 'a valid regex pattern',
              ),
              stackTrace,
            );
          }
          result.add(_PresetEntryStep(KeepByRegexTransformation(regex)));
        case 'skip-by-regex':
          final rawRegex = rawStep['regex'];
          final regexKey = [
            stepKey,
            'regex',
          ].join('.');
          if (rawRegex is! String) {
            throw ParsePresetStepsInvalidRawPresetStepMemberTypeFailure(
              key: regexKey,
              expectedType: String,
              value: rawRegex,
            );
          }
          final RegExp regex;
          try {
            regex = RegExp(rawRegex);
          } on Object catch (_, stackTrace) {
            Error.throwWithStackTrace(
              ParsePresetStepsInvalidRawPresetStepMemberValueFailure(
                key: regexKey,
                value: rawRegex,
                hint: 'a valid regex pattern',
              ),
              stackTrace,
            );
          }
          result.add(_PresetEntryStep(SkipByRegexTransformation(regex)));
        case 'keep-by-glob':
          final rawGlob = rawStep['glob'];
          final globKey = [
            stepKey,
            'glob',
          ].join('.');
          if (rawGlob is! String) {
            throw ParsePresetStepsInvalidRawPresetStepMemberTypeFailure(
              key: globKey,
              expectedType: String,
              value: rawGlob,
            );
          }
          late final Glob glob;
          try {
            glob = Glob(rawGlob, context: path.posix);
          } on Object catch (_, stackTrace) {
            Error.throwWithStackTrace(
              ParsePresetStepsInvalidRawPresetStepMemberValueFailure(
                key: globKey,
                value: rawGlob,
                hint: 'a valid glob pattern',
              ),
              stackTrace,
            );
          }
          result.add(_PresetEntryStep(KeepByGlobTransformation(glob)));
        case 'skip-by-glob':
          final rawGlob = rawStep['glob'];
          final globKey = [
            stepKey,
            'glob',
          ].join('.');
          if (rawGlob is! String) {
            throw ParsePresetStepsInvalidRawPresetStepMemberTypeFailure(
              key: globKey,
              expectedType: String,
              value: rawGlob,
            );
          }
          late final Glob glob;
          try {
            glob = Glob(rawGlob, context: path.posix);
          } on Object catch (_, stackTrace) {
            Error.throwWithStackTrace(
              ParsePresetStepsInvalidRawPresetStepMemberValueFailure(
                key: globKey,
                value: rawGlob,
                hint: 'a valid glob pattern',
              ),
              stackTrace,
            );
          }
          result.add(_PresetEntryStep(SkipByGlobTransformation(glob)));
        case 'relative':
          final basePath = rawStep['base-path'];
          final basePathKey = [
            stepKey,
            'base-path',
          ].join('.');
          if (basePath is! String) {
            throw ParsePresetStepsInvalidRawPresetStepMemberTypeFailure(
              key: basePathKey,
              expectedType: String,
              value: basePath,
            );
          }
          result.add(_PresetEntryStep(RelativeTransformation(basePath)));
        case 'preset':
          final presetName = rawStep['name'];
          final presetNameKey = [
            stepKey,
            'name',
          ].join('.');
          if (presetName is! String) {
            throw ParsePresetStepsInvalidRawPresetStepMemberTypeFailure(
              key: presetNameKey,
              expectedType: String,
              value: presetName,
            );
          }
          result.add(_PresetEntryRef(presetName));
        default:
          throw ParsePresetStepsInvalidRawPresetStepMemberValueFailure(
            key: stepTypeKey,
            value: rawType,
            hint: 'one of: keep-by-regex, skip-by-regex, keep-by-glob, '
                'skip-by-glob, relative, preset',
          );
      }
    }
    return result;
  }
}
