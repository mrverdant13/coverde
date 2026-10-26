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

int _width(dynamic value) {
  return _asNum(value).toInt();
}

num _asNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse('$value') ?? 0;
}
