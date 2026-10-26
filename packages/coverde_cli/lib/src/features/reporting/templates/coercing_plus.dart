import 'dart:math' as math;

/// Adds two values, coercing numeric strings the way Shopify Liquid does.
///
/// `--variable` values are strings.
/// `{{ variables["min-line-rate"] | plus: 0 }}` turns one into a number.
/// liquify's `plus` only accepts [num].
num coercingPlus(
  dynamic value,
  List<dynamic> arguments,
  Map<String, dynamic> namedArguments,
) {
  return _asNum(value) + _asNum(arguments.first);
}

/// Subtracts [arguments]'s first value, coercing numeric strings.
num coercingMinus(
  dynamic value,
  List<dynamic> arguments,
  Map<String, dynamic> namedArguments,
) {
  if (arguments.isEmpty) throw ArgumentError('minus expects 1 argument');
  return _asNum(value) - _asNum(arguments.first);
}

/// Multiplies by [arguments]'s first value, coercing numeric strings.
num coercingTimes(
  dynamic value,
  List<dynamic> arguments,
  Map<String, dynamic> namedArguments,
) {
  if (arguments.isEmpty) throw ArgumentError('times expects 1 argument');
  return _asNum(value) * _asNum(arguments.first);
}

/// Rounds a number, coercing numeric strings.
///
/// Null stays null. liquify's `round` turns null into 0.
dynamic coercingRound(
  dynamic value,
  List<dynamic> arguments,
  Map<String, dynamic> namedArguments,
) {
  if (value == null) return null;
  final number = _asNum(value);
  final places = arguments.isEmpty ? 0 : _asNum(arguments.first).toInt();
  final scale = math.pow(10, places).toDouble();
  return (number * scale).round() / scale;
}

num _asNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse('$value') ?? 0;
}
