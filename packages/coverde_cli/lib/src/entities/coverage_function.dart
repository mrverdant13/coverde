import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// {@template coverde.coverage_function}
/// Hit data for one function.
/// {@endtemplate}
@immutable
final class CoverageFunction {
  /// {@macro coverde.coverage_function}
  const CoverageFunction({
    required this.name,
    required this.line,
    required this.hits,
  });

  /// The function name from `FN:` or `FNDA:`.
  final String name;

  /// The 1-based line where the function starts.
  ///
  /// Null when the trace has `FNDA:` and no matching `FN:` record.
  final int? line;

  /// How many times this function was executed.
  ///
  /// Zero when the trace has `FN:` and no matching `FNDA:` record.
  final int hits;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CoverageFunction &&
        other.name == name &&
        other.line == line &&
        other.hits == hits;
  }

  @override
  int get hashCode => Object.hash(name, line, hits);
}

/// {@template coverde.coverage_functions}
/// Function coverage for one file.
///
/// A null group means the trace never mentioned functions. An instance with
/// [found] `0` means the trace reported that no functions exist.
/// {@endtemplate}
@immutable
final class CoverageFunctions {
  /// {@macro coverde.coverage_functions}
  CoverageFunctions({
    required this.hit,
    required this.found,
    required Iterable<CoverageFunction> functions,
  }) : functions = List<CoverageFunction>.unmodifiable(functions);

  /// How many functions were executed at least once.
  final int hit;

  /// How many functions were found.
  final int found;

  /// The functions in this group, sorted by name.
  final List<CoverageFunction> functions;

  static const _functionsEquality = ListEquality<CoverageFunction>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CoverageFunctions &&
        other.hit == hit &&
        other.found == found &&
        _functionsEquality.equals(other.functions, functions);
  }

  @override
  int get hashCode =>
      Object.hash(hit, found, _functionsEquality.hash(functions));
}
