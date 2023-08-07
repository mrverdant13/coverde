import 'package:meta/meta.dart';

/// {@template model_2}
/// A fake model 2.
/// {@endtemplate}
@immutable
class Model2 {
  /// {@macro model_2}
  const Model2({
    required this.intValue,
  });

  /// A fake int value.
  final int intValue;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Model2 && other.intValue == intValue;
  }

  @override
  int get hashCode => intValue.hashCode;
}
