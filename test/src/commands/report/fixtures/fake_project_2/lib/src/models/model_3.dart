import 'package:meta/meta.dart';

/// {@template model_3}
/// A fake model 3.
/// {@endtemplate}
@immutable
class Model3 {
  /// {@macro model_3}
  const Model3({
    required this.doubleValue,
  });

  /// A fake double value.
  final double doubleValue;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Model3 && other.doubleValue == doubleValue;
  }

  @override
  int get hashCode => doubleValue.hashCode;
}
