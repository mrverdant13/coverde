import 'package:meta/meta.dart';

/// One non-blank line from an LCOV record, in trace order.
@immutable
sealed class CoverageTraceEntry {
  const CoverageTraceEntry();
}

/// The `SF:` line of a record.
///
/// Rendering uses the coverage file path.
final class CoverageSourceEntry extends CoverageTraceEntry {
  /// Creates the source-path entry.
  const CoverageSourceEntry();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CoverageSourceEntry;
  }

  @override
  int get hashCode => runtimeType.hashCode;
}

/// A trimmed line the parser already understands.
final class CoveragePreservedEntry extends CoverageTraceEntry {
  /// Creates a preserved line from [text].
  const CoveragePreservedEntry(this.text);

  /// The trimmed LCOV line, including its tag.
  final String text;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CoveragePreservedEntry && other.text == text;
  }

  @override
  int get hashCode => Object.hash(runtimeType, text);
}

/// A trimmed line the parser does not understand.
final class CoverageUnrecognizedEntry extends CoverageTraceEntry {
  /// Creates an unrecognized line from [text].
  const CoverageUnrecognizedEntry(this.text);

  /// The trimmed line text.
  final String text;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CoverageUnrecognizedEntry && other.text == text;
  }

  @override
  int get hashCode => Object.hash(runtimeType, text);
}
