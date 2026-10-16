import 'package:meta/meta.dart';

/// {@template coverde.coverage_line}
/// Hit data for one instrumented line.
/// {@endtemplate}
@immutable
final class CoverageLine {
  /// {@macro coverde.coverage_line}
  const CoverageLine({required this.number, required this.hits, this.checksum});

  /// The 1-based line number in the source file.
  final int number;

  /// How many times this line was executed.
  final int hits;

  /// The optional LCOV checksum for this line.
  final int? checksum;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CoverageLine &&
        other.number == number &&
        other.hits == hits &&
        other.checksum == checksum;
  }

  @override
  int get hashCode => Object.hash(number, hits, checksum);
}
