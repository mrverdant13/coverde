import 'package:meta/meta.dart';

/// {@template model_1}
/// A fake model 1.
/// {@endtemplate}
@immutable
class Model1 {
  /// {@macro model_1}
  const Model1({
    required this.stringValue,
  });

  /// A fake string value.
  final String stringValue;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Model1 && other.stringValue == stringValue;
  }

  @override
  int get hashCode => stringValue.hashCode;
}
