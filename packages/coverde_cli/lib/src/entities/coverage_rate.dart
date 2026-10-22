/// The percentage of [hit] over [found], from 0 to 100.
///
/// Returns null when [found] is 0. A missing measurement is not 0%.
double? coverageRate({required int hit, required int found}) {
  if (found == 0) return null;
  return (hit * 100) / found;
}
