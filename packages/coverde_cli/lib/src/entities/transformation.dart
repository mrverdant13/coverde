import 'package:meta/meta.dart';

/// {@template transformation}
/// A transformation step to apply to coverage trace file paths.
/// {@endtemplate}
@immutable
sealed class Transformation {
  /// {@macro transformation}
  const Transformation(
    this.fromPreset,
  );

  /// The preset name this transformation was expanded from, if any.
  final String? fromPreset;

  /// Human-readable description of this transformation.
  String get describe;

  /// Creates a copy with the given [fromPreset].
  Transformation copyWith({
    String? fromPreset,
  });
}

/// {@template keep_by_regex_transformation}
/// Keeps only files whose path matches the [regex].
/// {@endtemplate}
@immutable
final class KeepByRegexTransformation extends Transformation {
  /// {@macro keep_by_regex_transformation}
  const KeepByRegexTransformation(
    this.regex,
    super.fromPreset,
  );

  /// The regex pattern to match.
  final String regex;

  @override
  String get describe => 'keep-by-regex $regex';

  @override
  Transformation copyWith({
    String? fromPreset,
  }) {
    return KeepByRegexTransformation(
      regex,
      fromPreset ?? this.fromPreset,
    );
  }
}

/// {@template skip_by_regex_transformation}
/// Skips files whose path matches the [regex].
/// {@endtemplate}
@immutable
final class SkipByRegexTransformation extends Transformation {
  /// {@macro skip_by_regex_transformation}
  const SkipByRegexTransformation(
    this.regex,
    super.fromPreset,
  );

  /// The regex pattern to match.
  final String regex;

  @override
  String get describe => 'skip-by-regex $regex';

  @override
  Transformation copyWith({
    String? fromPreset,
  }) {
    return SkipByRegexTransformation(
      regex,
      fromPreset ?? this.fromPreset,
    );
  }
}

/// {@template keep_by_glob_transformation}
/// Keeps only files whose path matches the [glob].
/// {@endtemplate}
@immutable
final class KeepByGlobTransformation extends Transformation {
  /// {@macro keep_by_glob_transformation}
  const KeepByGlobTransformation(
    this.glob,
    super.fromPreset,
  );

  /// The glob pattern to match.
  final String glob;

  @override
  String get describe => 'keep-by-glob $glob';

  @override
  Transformation copyWith({
    String? fromPreset,
  }) {
    return KeepByGlobTransformation(
      glob,
      fromPreset ?? this.fromPreset,
    );
  }
}

/// {@template skip_by_glob_transformation}
/// Skips files whose path matches the [glob].
/// {@endtemplate}
@immutable
final class SkipByGlobTransformation extends Transformation {
  /// {@macro skip_by_glob_transformation}
  const SkipByGlobTransformation(
    this.glob,
    super.fromPreset,
  );

  /// The glob pattern to match.
  final String glob;

  @override
  String get describe => 'skip-by-glob $glob';

  @override
  Transformation copyWith({
    String? fromPreset,
  }) {
    return SkipByGlobTransformation(
      glob,
      fromPreset ?? this.fromPreset,
    );
  }
}

/// {@template relative_transformation}
/// Rewrites file paths to be relative to [basePath].
/// {@endtemplate}
@immutable
final class RelativeTransformation extends Transformation {
  /// {@macro relative_transformation}
  const RelativeTransformation(
    this.basePath,
    super.fromPreset,
  );

  /// The base path to rewrite file paths to be relative to.
  final String basePath;

  @override
  String get describe => 'relative base-path=$basePath';

  @override
  Transformation copyWith({
    String? fromPreset,
  }) {
    return RelativeTransformation(
      basePath,
      fromPreset ?? this.fromPreset,
    );
  }
}
