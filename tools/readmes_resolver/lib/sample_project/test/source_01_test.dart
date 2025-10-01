import 'package:sample_project/source_01.dart';
import 'package:test/test.dart';

void main() {
  test('add', () {
    expect(add(1, 2), 3);
  });

  test('multiply', () {
    expect(multiply(2, 3), 6);
  });

  test('divide', () {
    expect(divide(6, 3), 2);
  });

  test('power', () {
    expect(power(2, 3), 8);
  });
}
