/// The percentage of [hit] over [found], from 0 to 100.
///
/// Returns null when [found] is 0. A missing measurement is not 0%.
double? coverageRate({required int hit, required int found}) {
  if (found == 0) return null;
  return (hit * 100) / found;
}

/// The percentage of [hit] over [found] when the measurement exists.
///
/// Returns null when [hit] or [found] is null, and when [found] is 0.
double? optionalCoverageRate({required int? hit, required int? found}) {
  if (hit == null || found == null) return null;
  return coverageRate(hit: hit, found: found);
}
