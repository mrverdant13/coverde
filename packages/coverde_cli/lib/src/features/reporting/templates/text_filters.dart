/// Prints [value] with a fixed number of fraction digits.
///
/// Null stays null. `100 | fixed: 2` is `100.00`.
dynamic fixed(
  dynamic value,
  List<dynamic> arguments,
  Map<String, dynamic> namedArguments,
) {
  if (value == null) return null;
  final places = arguments.isEmpty ? 0 : _width(arguments.first);
  return _asNum(value).toStringAsFixed(places);
}

/// Pads [value] with spaces to a width.
///
/// The default aligns left. A second argument of `right` aligns right.
/// Text that is already long enough is returned unchanged.
String pad(
  dynamic value,
  List<dynamic> arguments,
  Map<String, dynamic> namedArguments,
) {
  final text = value == null ? '' : '$value';
  final width = _width(arguments.first);
  if (text.length >= width) return text;
  final spaces = ' ' * (width - text.length);
  final right = arguments.length > 1 && arguments[1] == 'right';
  return right ? '$spaces$text' : '$text$spaces';
}

/// Keeps the tail of [value] and prefixes `...` when it is longer than the
/// width.
String truncate(
  dynamic value,
  List<dynamic> arguments,
  Map<String, dynamic> namedArguments,
) {
  final text = value == null ? '' : '$value';
  final width = _width(arguments.first);
  if (text.length <= width || width < 0) return text;
  if (width <= 3) return text.substring(text.length - width);
  final keep = width - 3;
  return '...${text.substring(text.length - keep)}';
}

/// Sorts file or directory maps by a rate field.
///
/// Null rates stay after numbers. The direction is `asc`, the default, or
/// `desc`. Equal rates keep their previous order.
dynamic sortByRate(
  dynamic value,
  List<dynamic> arguments,
  Map<String, dynamic> namedArguments,
) {
  if (value is! List) return value;
  final field = arguments.isEmpty ? 'lineRate' : '${arguments.first}';
  final descending = arguments.length > 1 && arguments[1] == 'desc';
  final indexed =
      [for (var index = 0; index < value.length; index++) (value[index], index)]
        ..sort((left, right) {
          final order = _compareRates(
            _rate(left.$1, field),
            _rate(right.$1, field),
            descending: descending,
          );
          if (order != 0) return order;
          return left.$2.compareTo(right.$2);
        });
  return [for (final entry in indexed) entry.$1];
}

int _compareRates(double? left, double? right, {required bool descending}) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  final order = left.compareTo(right);
  return descending ? -order : order;
}

double? _rate(dynamic item, String field) {
  if (item is! Map) return null;
  final value = item[field];
  if (value is! num) return null;
  return value.toDouble();
}

int _width(dynamic value) {
  return _asNum(value).toInt();
}

num _asNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse('$value') ?? 0;
}
