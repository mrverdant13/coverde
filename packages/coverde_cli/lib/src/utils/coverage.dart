/// Extension on a coverage [num] value to validate it.
extension CoverageValue<T extends num> on T {
  /// Validate coverage value.
  T checkedAsCoverage({String? valueName}) {
    final coverageValueName = valueName ?? 'coverage';
    if (isNegative) {
      throw ArgumentError('The $coverageValueName value should be positive.');
    } else if (this > 100) {
      throw ArgumentError(
        'The $coverageValueName value should not be greater than 100.',
      );
    }
    return this;
  }
}

/// The percentage of [hit] over [found], from 0 to 100.
///
/// Returns null when [found] is 0. A missing measurement is not 0%.
double? coverageRate({required int hit, required int found}) {
  if (found == 0) return null;
  return (hit * 100) / found;
}
