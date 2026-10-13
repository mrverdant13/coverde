part of 'coverde_config.dart';

/// YAML keys used when parsing coverde.yaml.
extension _CoverdeConfigYamlKeys on CoverdeConfig {
  /// Root-level key for the transformations/presets map.
  static const transformations = 'transformations';

  /// Root-level key for named coverage thresholds.
  static const coverage = 'coverage';

  /// Preset step map key for the transformation type.
  static const stepType = 'type';

  /// Preset step map key for regex pattern (keep-by-regex, skip-by-regex).
  static const stepRegex = 'regex';

  /// Preset step map key for glob pattern (keep-by-glob, skip-by-glob).
  static const stepGlob = 'glob';

  /// Preset step map key for numeric comparison (keep-by-coverage,
  /// skip-by-coverage).
  static const stepComparison = 'comparison';

  /// Preset step map key for base path (relative).
  static const stepBasePath = 'base-path';

  /// Preset step map key for preset name (preset reference).
  static const stepName = 'name';

  /// Preset step map key for an external preset file path.
  static const stepFile = 'file';
}

/// Parses a [CoverdeConfig] from a YAML string.
///
/// Throws [CoverdeConfigFromYamlFailure] when an error occurs.
CoverdeConfig _parseCoverdeConfigFromYaml(
  String yamlString, {
  required String baseDirectory,
}) {
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
  final rawPresets = _parseRawPresets(rawConfig, baseDirectory: baseDirectory);
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
  final coverageThresholds = _parseCoverageThresholds(rawConfig);
  return CoverdeConfig(
    presets: presets,
    coverageThresholds: coverageThresholds,
  );
}

/// Parses the `coverage` map of named thresholds.
///
/// A missing `coverage` member yields an empty map.
///
/// Throws [CoverdeConfigFromYamlFailure] when the member is present but
/// invalid.
Map<String, double> _parseCoverageThresholds(yaml.YamlMap rawConfig) {
  final rawCoverage = rawConfig[_CoverdeConfigYamlKeys.coverage];
  if (rawCoverage == null) return const {};
  if (rawCoverage is! yaml.YamlMap) {
    throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
      key: _CoverdeConfigYamlKeys.coverage,
      expectedType: yaml.YamlMap,
      value: rawCoverage,
    );
  }
  final result = <String, double>{};
  for (final MapEntry(key: rawKey, value: rawValue) in rawCoverage.entries) {
    final keyPath = [
      _CoverdeConfigYamlKeys.coverage,
      '[key=$rawKey]',
    ].join('.');
    if (rawKey is! String) {
      throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
        key: keyPath,
        expectedType: String,
        value: rawKey,
      );
    }
    if (rawKey.isEmpty || double.tryParse(rawKey) != null) {
      throw CoverdeConfigFromYamlInvalidYamlMemberValueFailure(
        key: keyPath,
        value: rawKey,
        hint: 'a non-empty name that is not a number',
      );
    }
    final valueKey = [_CoverdeConfigYamlKeys.coverage, rawKey].join('.');
    if (rawValue is! num) {
      throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
        key: valueKey,
        expectedType: num,
        value: rawValue,
      );
    }
    if (!_isCoveragePercentage(rawValue)) {
      throw CoverdeConfigFromYamlInvalidCoveragePercentageFailure(
        key: valueKey,
        invalidReferences: [rawValue.toDouble()],
      );
    }
    result[rawKey] = rawValue.toDouble();
  }
  return Map.unmodifiable(result);
}

/// Whether [value] is a finite percentage in the inclusive range 0-100.
bool _isCoveragePercentage(num value) {
  return value.isFinite && value >= 0 && value <= 100;
}

Map<String, List<_PresetEntry>> _parseRawPresets(
  yaml.YamlMap rawConfig, {
  required String baseDirectory,
}) {
  final rawPresets = rawConfig[_CoverdeConfigYamlKeys.transformations];
  if (rawPresets == null) return {};
  if (rawPresets is! yaml.YamlMap) {
    throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
      key: _CoverdeConfigYamlKeys.transformations,
      expectedType: yaml.YamlMap,
      value: rawPresets,
    );
  }
  final result = <String, List<_PresetEntry>>{};
  for (final MapEntry(key: presetName, value: rawSteps) in rawPresets.entries) {
    if (presetName is! String) {
      throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
        key: [
          _CoverdeConfigYamlKeys.transformations,
          '[key=$presetName]',
        ].join('.'),
        expectedType: String,
        value: presetName,
      );
    }
    final presetKey = [
      _CoverdeConfigYamlKeys.transformations,
      presetName,
    ].join('.');
    if (rawSteps is! yaml.YamlList) {
      throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
        key: presetKey,
        expectedType: yaml.YamlList,
        value: rawSteps,
      );
    }
    result[presetName] = _parsePresetSteps(
      rawSteps,
      keyPrefix: presetKey,
      baseDirectory: baseDirectory,
    );
  }
  return result;
}

List<_PresetEntry> _parsePresetSteps(
  yaml.YamlList list, {
  required String keyPrefix,
  required String baseDirectory,
}) {
  if (list.isEmpty) return [];
  final result = <_PresetEntry>[];
  for (final (index, rawStep) in list.indexed) {
    final stepKey = [keyPrefix, '[$index]'].join('.');
    if (rawStep is! yaml.YamlMap) {
      throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
        key: stepKey,
        expectedType: yaml.YamlMap,
        value: rawStep,
      );
    }
    final rawType = rawStep[_CoverdeConfigYamlKeys.stepType];
    final stepTypeKey = [stepKey, _CoverdeConfigYamlKeys.stepType].join('.');
    if (rawType is! String) {
      throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
        key: stepTypeKey,
        expectedType: String,
        value: rawType,
      );
    }
    switch (rawType) {
      case KeepByRegexTransformation.identifier:
        final rawRegex = rawStep[_CoverdeConfigYamlKeys.stepRegex];
        final regexKey = [stepKey, _CoverdeConfigYamlKeys.stepRegex].join('.');
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
        final rawRegex = rawStep[_CoverdeConfigYamlKeys.stepRegex];
        final regexKey = [stepKey, _CoverdeConfigYamlKeys.stepRegex].join('.');
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
        final rawGlob = rawStep[_CoverdeConfigYamlKeys.stepGlob];
        final globKey = [stepKey, _CoverdeConfigYamlKeys.stepGlob].join('.');
        if (rawGlob is! String) {
          throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
            key: globKey,
            expectedType: String,
            value: rawGlob,
          );
        }
        final Glob glob;
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
        final rawGlob = rawStep[_CoverdeConfigYamlKeys.stepGlob];
        final globKey = [stepKey, _CoverdeConfigYamlKeys.stepGlob].join('.');
        if (rawGlob is! String) {
          throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
            key: globKey,
            expectedType: String,
            value: rawGlob,
          );
        }
        final Glob glob;
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
      case KeepByCoverageTransformation.identifier:
        final rawComparison = rawStep[_CoverdeConfigYamlKeys.stepComparison];
        final comparisonKey = [
          stepKey,
          _CoverdeConfigYamlKeys.stepComparison,
        ].join('.');
        if (rawComparison is! String) {
          throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
            key: comparisonKey,
            expectedType: String,
            value: rawComparison,
          );
        }
        final NumericComparison<double> comparison;
        try {
          comparison = NumericComparison.fromDescription(
            rawComparison,
            double.parse,
          );
        } on Object catch (_, stackTrace) {
          Error.throwWithStackTrace(
            CoverdeConfigFromYamlInvalidYamlMemberValueFailure(
              key: comparisonKey,
              value: rawComparison,
              hint: 'a valid numeric comparison',
            ),
            stackTrace,
          );
        }
        final invalidReferences = validateCoverageReferences(comparison);
        if (invalidReferences.isNotEmpty) {
          throw CoverdeConfigFromYamlInvalidCoveragePercentageFailure(
            key: comparisonKey,
            invalidReferences: invalidReferences,
          );
        }
        result.add(
          _PresetEntryStep(
            KeepByCoverageTransformation(comparison: comparison),
          ),
        );
      case SkipByCoverageTransformation.identifier:
        final rawComparison = rawStep[_CoverdeConfigYamlKeys.stepComparison];
        final comparisonKey = [
          stepKey,
          _CoverdeConfigYamlKeys.stepComparison,
        ].join('.');
        if (rawComparison is! String) {
          throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
            key: comparisonKey,
            expectedType: String,
            value: rawComparison,
          );
        }
        final NumericComparison<double> comparison;
        try {
          comparison = NumericComparison.fromDescription(
            rawComparison,
            double.parse,
          );
        } on Object catch (_, stackTrace) {
          Error.throwWithStackTrace(
            CoverdeConfigFromYamlInvalidYamlMemberValueFailure(
              key: comparisonKey,
              value: rawComparison,
              hint: 'a valid numeric comparison',
            ),
            stackTrace,
          );
        }
        final invalidReferences = validateCoverageReferences(comparison);
        if (invalidReferences.isNotEmpty) {
          throw CoverdeConfigFromYamlInvalidCoveragePercentageFailure(
            key: comparisonKey,
            invalidReferences: invalidReferences,
          );
        }
        result.add(
          _PresetEntryStep(
            SkipByCoverageTransformation(comparison: comparison),
          ),
        );
      case RelativeTransformation.identifier:
        final basePath = rawStep[_CoverdeConfigYamlKeys.stepBasePath];
        final basePathKey = [
          stepKey,
          _CoverdeConfigYamlKeys.stepBasePath,
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
        const allowedKeys = {
          _CoverdeConfigYamlKeys.stepType,
          _CoverdeConfigYamlKeys.stepName,
          _CoverdeConfigYamlKeys.stepFile,
        };
        for (final key in rawStep.keys) {
          if (key is! String || !allowedKeys.contains(key)) {
            throw CoverdeConfigFromYamlInvalidYamlMemberValueFailure(
              key: stepKey,
              value: key,
              hint: 'only `type`, `name`, and `file`',
            );
          }
        }
        final presetName = rawStep[_CoverdeConfigYamlKeys.stepName];
        final presetNameKey = [
          stepKey,
          _CoverdeConfigYamlKeys.stepName,
        ].join('.');
        if (presetName is! String) {
          throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
            key: presetNameKey,
            expectedType: String,
            value: presetName,
          );
        }
        if (presetName.isEmpty) {
          throw CoverdeConfigFromYamlInvalidYamlMemberValueFailure(
            key: presetNameKey,
            value: presetName,
            hint: 'a non-empty string',
          );
        }
        if (!rawStep.containsKey(_CoverdeConfigYamlKeys.stepFile)) {
          result.add(_PresetEntryRef(presetName));
          break;
        }
        final rawFile = rawStep[_CoverdeConfigYamlKeys.stepFile];
        final fileKey = [stepKey, _CoverdeConfigYamlKeys.stepFile].join('.');
        if (rawFile is! String) {
          throw CoverdeConfigFromYamlInvalidYamlMemberTypeFailure(
            key: fileKey,
            expectedType: String,
            value: rawFile,
          );
        }
        if (rawFile.isEmpty) {
          throw CoverdeConfigFromYamlInvalidYamlMemberValueFailure(
            key: fileKey,
            value: rawFile,
            hint: 'a non-empty string',
          );
        }
        result.add(
          _PresetEntryStep(
            ExternalPresetTransformation(
              filePath: rawFile,
              presetName: presetName,
              baseDirectory: baseDirectory,
            ),
          ),
        );
      default:
        final availableIdentifiers = Transformation.identifiers
            .map((e) => '`$e`')
            .join(', ');
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
      case _PresetEntryStep(:final step):
        result.add(step);
      case _PresetEntryRef(:final name):
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
