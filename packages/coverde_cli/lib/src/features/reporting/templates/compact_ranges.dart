/// Turns sorted or unsorted line numbers into a compact range list.
///
/// `3, 4, 5, 10` becomes `3-5, 10`. An empty input becomes an empty string.
String compactRanges(
  dynamic value,
  List<dynamic> arguments,
  Map<String, dynamic> namedArguments,
) {
  if (value is! Iterable) return '';
  final numbers =
      value.whereType<num>().map((number) => number.toInt()).toSet().toList()
        ..sort();
  if (numbers.isEmpty) return '';
  final ranges = <String>[];
  var start = numbers.first;
  var previous = numbers.first;
  for (final number in numbers.skip(1)) {
    if (number == previous + 1) {
      previous = number;
      continue;
    }
    ranges.add(start == previous ? '$start' : '$start-$previous');
    start = number;
    previous = number;
  }
  ranges.add(start == previous ? '$start' : '$start-$previous');
  return ranges.join(', ');
}
