import 'package:glob/glob.dart';
import 'package:meta/meta.dart';

/// Separator used when showing nested preset hierarchy (e.g. "preset-a →
/// preset-b").
const String presetChainSeparator = ' → ';

/// {@template transformation}
/// A transformation step to apply to coverage trace file paths.
/// {@endtemplate}
@immutable
sealed class Transformation {
  /// {@macro transformation}
  const Transformation();

  factory Transformation.fromCliOption(
    String option, {
    List<PresetTransformation> presets = const [],
  }) {
    final [identifier, ...rest] = option.split('=');
    final argument = rest.join('=');
    switch (identifier) {
      case 'keep-by-regex':
        final regex = RegExp(argument);
        return KeepByRegexTransformation(regex);
      case 'skip-by-regex':
        final regex = RegExp(argument);
        return SkipByRegexTransformation(regex);
      case 'keep-by-glob':
        final glob = Glob(argument);
        return KeepByGlobTransformation(glob);
      case 'skip-by-glob':
        final glob = Glob(argument);
        return SkipByGlobTransformation(glob);
      case 'relative':
        final basePath = argument;
        return RelativeTransformation(basePath);
      case 'preset':
        final presetName = argument;
        return presets.singleWhere(
          (p) => p.presetName == presetName,
          // TODO(mrverdant13): Use custom failure.
          orElse: () => throw StateError('Unknown preset: $presetName'),
        );
      default:
        // TODO(mrverdant13): Use custom failure.
        throw UnsupportedError('Unsupported transformation: $identifier');
    }
  }

  factory Transformation.fromJson(
    Map<String, dynamic> json, {
    List<PresetTransformation> presets = const [],
  }) {
    switch (json['type']) {
      case 'keep-by-regex':
        final regex = RegExp(json['regex'] as String);
        return KeepByRegexTransformation(regex);
      case 'skip-by-regex':
        final regex = RegExp(json['regex'] as String);
        return SkipByRegexTransformation(regex);
      case 'keep-by-glob':
        final glob = Glob(json['glob'] as String);
        return KeepByGlobTransformation(glob);
      case 'skip-by-glob':
        final glob = Glob(json['glob'] as String);
        return SkipByGlobTransformation(glob);
      case 'relative':
        final basePath = json['base-path'] as String;
        return RelativeTransformation(basePath);
      case 'preset':
        final presetName = json['name'] as String;
        return presets.singleWhere(
          (p) => p.presetName == presetName,
          // TODO(mrverdant13): Use custom failure.
          orElse: () => throw StateError('Unknown preset: $presetName'),
        );
      default:
        // TODO(mrverdant13): Use custom failure.
        throw UnsupportedError('Unsupported transformation: ${json['type']}');
    }
  }

  /// Human-readable description of this transformation.
  String get describe;

  /// Flattens this transformation to leaf steps only.
  ///
  /// [PresetTransformation] is expanded; leaf transformations return
  /// themselves.
  Iterable<Transformation> get flattenedSteps sync* {
    switch (this) {
      case PresetTransformation(:final steps):
        yield* steps.expand((s) => s.flattenedSteps);
      default:
        yield this;
    }
  }

  /// Yields each leaf step with its preset chain (outermost first).
  ///
  /// Used to show "from preset a → b" for nested presets.
  Iterable<
      ({
        List<String> presets,
        Transformation transformation,
      })> stepsWithPresetChains([
    List<String> precedingPresets = const [],
  ]) sync* {
    switch (this) {
      case PresetTransformation(:final presetName, :final steps):
        yield* steps.expand(
          (s) => s.stepsWithPresetChains([
            ...precedingPresets,
            presetName,
          ]),
        );
      default:
        yield (
          presets: precedingPresets,
          transformation: this,
        );
    }
  }
}

/// {@template preset_transformation}
/// Groups a set of transformations under a preset name (may include nested
/// [PresetTransformation]s).
/// {@endtemplate}
@immutable
final class PresetTransformation extends Transformation {
  /// {@macro preset_transformation}
  const PresetTransformation({
    required this.presetName,
    required this.steps,
  });

  /// The preset name.
  final String presetName;

  /// The transformations in this preset (may include nested
  /// [PresetTransformation]s).
  final List<Transformation> steps;

  @override
  String get describe => 'preset $presetName';
}

/// {@template keep_by_regex_transformation}
/// Keeps only files whose path matches the [regex].
/// {@endtemplate}
@immutable
final class KeepByRegexTransformation extends Transformation {
  /// {@macro keep_by_regex_transformation}
  const KeepByRegexTransformation(this.regex);

  /// The regex pattern to match.
  final RegExp regex;

  @override
  String get describe => 'keep-by-regex ${regex.pattern}';
}

/// {@template skip_by_regex_transformation}
/// Skips files whose path matches the [regex].
/// {@endtemplate}
@immutable
final class SkipByRegexTransformation extends Transformation {
  /// {@macro skip_by_regex_transformation}
  const SkipByRegexTransformation(this.regex);

  /// The regex pattern to match.
  final RegExp regex;

  @override
  String get describe => 'skip-by-regex ${regex.pattern}';
}

/// {@template keep_by_glob_transformation}
/// Keeps only files whose path matches the [glob].
/// {@endtemplate}
@immutable
final class KeepByGlobTransformation extends Transformation {
  /// {@macro keep_by_glob_transformation}
  const KeepByGlobTransformation(this.glob);

  /// The glob pattern to match.
  final Glob glob;

  @override
  String get describe => 'keep-by-glob ${glob.pattern}';
}

/// {@template skip_by_glob_transformation}
/// Skips files whose path matches the [glob].
/// {@endtemplate}
@immutable
final class SkipByGlobTransformation extends Transformation {
  /// {@macro skip_by_glob_transformation}
  const SkipByGlobTransformation(this.glob);

  /// The glob pattern to match.
  final Glob glob;

  @override
  String get describe => 'skip-by-glob ${glob.pattern}';
}

/// {@template relative_transformation}
/// Rewrites file paths to be relative to [basePath].
/// {@endtemplate}
@immutable
final class RelativeTransformation extends Transformation {
  /// {@macro relative_transformation}
  const RelativeTransformation(this.basePath);

  /// The base path to rewrite file paths to be relative to.
  final String basePath;

  @override
  String get describe => 'relative base-path=$basePath';
}
