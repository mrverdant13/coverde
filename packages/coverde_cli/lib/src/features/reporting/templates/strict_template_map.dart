import 'package:collection/collection.dart';
import 'package:coverde/src/features/reporting/failures/coverage_report_failure.dart';

/// A map that fails when a template reads a key that was not provided.
///
/// A present key whose value is null is a real null, not an unknown variable.
final class StrictTemplateMap extends DelegatingMap<String, Object?> {
  /// Creates a map containing [base].
  StrictTemplateMap(super.base);

  @override
  Object? operator [](Object? key) {
    if (!super.containsKey(key)) {
      throw CoverageTemplateRenderFailure(
        readableMessage: 'Unknown template variable `$key`.',
      );
    }
    return super[key];
  }

  @override
  void operator []=(String key, Object? value) {
    if (!super.containsKey(key)) {
      throw CoverageTemplateRenderFailure(
        readableMessage: 'Unknown template variable `$key`.',
      );
    }
    super[key] = value;
  }

  @override
  bool containsKey(Object? key) {
    if (!super.containsKey(key)) {
      throw CoverageTemplateRenderFailure(
        readableMessage: 'Unknown template variable `$key`.',
      );
    }
    return true;
  }
}
