part of 'coverde_config.dart';

/// Parses a [CoverdeConfig] from a YAML string.
///
/// Throws [CoverdeConfigFromYamlFailure] when an error occurs.
CoverdeConfig _parseCoverdeConfigFromYaml(String yamlString) {
  final dynamic rawConfig;
  try {
    rawConfig = yaml.loadYaml(yamlString);
  } on yaml.YamlException catch (exception) {
    throw CoverdeConfigFromYamlInvalidYamlFailure(
      yamlString: yamlString,
      yamlException: exception,
    );
  }
  if (rawConfig is! yaml.YamlMap) {
    throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
      key: null,
      expectedType: yaml.YamlMap,
      value: rawConfig,
    );
  }
  final rawPresets = _parseRawPresets(rawConfig);
  final presets = [
    for (final presetName in rawPresets.keys)
      PresetTransformation(
        presetName: presetName,
        steps: _expandPreset(
          presetName: presetName,
          presets: rawPresets,
          visiting: <String>{},
        ),
      ),
  ];
  return CoverdeConfig(
    presets: presets,
  );
}

Map<String, List<_PresetEntry>> _parseRawPresets(
  yaml.YamlMap rawConfig,
) {
  final rawPresets = rawConfig['transformations'];
  if (rawPresets == null) return {};
  if (rawPresets is! yaml.YamlMap) {
    throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
      key: null,
      expectedType: Map<String, yaml.YamlMap>,
      value: rawPresets,
    );
  }
  final result = <String, List<_PresetEntry>>{};
  for (final MapEntry(key: presetName, value: rawSteps) in rawPresets.entries) {
    final presetKey = '[key=$presetName]';
    if (presetName is! String) {
      throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
        key: presetKey,
        expectedType: MapEntry<String, yaml.YamlList>,
        value: presetName,
      );
    }
    if (rawSteps is! List) {
      throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
        key: presetKey,
        expectedType: List<yaml.YamlMap>,
        value: rawSteps,
      );
    }
    result[presetName] = _parsePresetSteps(rawSteps, keyPrefix: presetKey);
  }
  return result;
}

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
      throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
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
      throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
        key: stepTypeKey,
        expectedType: String,
        value: rawType,
      );
    }
    switch (rawType) {
      case KeepByRegexTransformation.identifier:
        final rawRegex = rawStep['regex'];
        final regexKey = [
          stepKey,
          'regex',
        ].join('.');
        if (rawRegex is! String) {
          throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
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
            CoverdeConfigFromYamlInvalidYamlMemberValueFailure(
              key: regexKey,
              value: rawRegex,
              hint: 'a valid regex pattern',
            ),
            stackTrace,
          );
        }
        result.add(_PresetEntryStep(KeepByRegexTransformation(regex)));
      case SkipByRegexTransformation.identifier:
        final rawRegex = rawStep['regex'];
        final regexKey = [
          stepKey,
          'regex',
        ].join('.');
        if (rawRegex is! String) {
          throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
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
            CoverdeConfigFromYamlInvalidYamlMemberValueFailure(
              key: regexKey,
              value: rawRegex,
              hint: 'a valid regex pattern',
            ),
            stackTrace,
          );
        }
        result.add(_PresetEntryStep(SkipByRegexTransformation(regex)));
      case KeepByGlobTransformation.identifier:
        final rawGlob = rawStep['glob'];
        final globKey = [
          stepKey,
          'glob',
        ].join('.');
        if (rawGlob is! String) {
          throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
            key: globKey,
            expectedType: String,
            value: rawGlob,
          );
        }
        late final Glob glob;
        try {
          glob = Glob(rawGlob, context: p.posix);
        } on Object catch (_, stackTrace) {
          Error.throwWithStackTrace(
            CoverdeConfigFromYamlInvalidYamlMemberValueFailure(
              key: globKey,
              value: rawGlob,
              hint: 'a valid glob pattern',
            ),
            stackTrace,
          );
        }
        result.add(_PresetEntryStep(KeepByGlobTransformation(glob)));
      case SkipByGlobTransformation.identifier:
        final rawGlob = rawStep['glob'];
        final globKey = [
          stepKey,
          'glob',
        ].join('.');
        if (rawGlob is! String) {
          throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
            key: globKey,
            expectedType: String,
            value: rawGlob,
          );
        }
        late final Glob glob;
        try {
          glob = Glob(rawGlob, context: p.posix);
        } on Object catch (_, stackTrace) {
          Error.throwWithStackTrace(
            CoverdeConfigFromYamlInvalidYamlMemberValueFailure(
              key: globKey,
              value: rawGlob,
              hint: 'a valid glob pattern',
            ),
            stackTrace,
          );
        }
        result.add(_PresetEntryStep(SkipByGlobTransformation(glob)));
      case RelativeTransformation.identifier:
        final basePath = rawStep['base-path'];
        final basePathKey = [
          stepKey,
          'base-path',
        ].join('.');
        if (basePath is! String) {
          throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
            key: basePathKey,
            expectedType: String,
            value: basePath,
          );
        }
        result.add(_PresetEntryStep(RelativeTransformation(basePath)));
      case PresetTransformation.identifier:
        final presetName = rawStep['name'];
        final presetNameKey = [
          stepKey,
          'name',
        ].join('.');
        if (presetName is! String) {
          throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
            key: presetNameKey,
            expectedType: String,
            value: presetName,
          );
        }
        result.add(_PresetEntryRef(presetName));
      default:
        final availableIdentifiers =
            Transformation.identifiers.map((e) => '`$e`').join(', ');
        throw CoverdeConfigFromYamlInvalidYamlMemberValueFailure(
          key: stepTypeKey,
          value: rawType,
          hint: 'one of: $availableIdentifiers',
        );
    }
  }
  return result;
}

List<Transformation> _expandPreset({
  required String presetName,
  required Map<String, List<_PresetEntry>> presets,
  required Set<String> visiting,
}) {
  final entries = presets[presetName];
  if (entries == null) {
    throw CoverdeConfigFromYamlUnknownPresetFailure(
      unknownPreset: presetName,
      availablePresets: presets.keys.toList()..sort(),
    );
  }
  if (visiting.contains(presetName)) {
    throw CoverdeConfigFromYamlPresetCycleFailure(
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
