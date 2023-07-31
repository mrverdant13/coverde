/// {@template custom_exception}
/// A fake custom exception.
/// {@endtemplate}
class CustomException implements Exception {
  /// {@macro custom_exception}
  const CustomException({
    required this.message,
  });

  /// A fake exception message.
  final String message;
}
