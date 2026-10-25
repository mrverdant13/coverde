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

num _asNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse('$value') ?? 0;
}
