import 'dart:math' as math;

import 'package:test/test.dart';

void main() {
  int? randomValue;

  setUp(() {
    randomValue = math.Random().nextInt(100);
  });

  tearDown(() {
    randomValue = null;
  });

  test('dummy test 1', () {
    expect(randomValue, isNotNull);
  });

  test('dummy test 2', () {
    expect(randomValue, isNotNull);
  });

  group('dummy group', () {
    String? otherValue;

    setUp(() {
      otherValue = math.Random().nextInt(100).toString();
    });

    tearDown(() {
      otherValue = null;
    });

    test('dummy test 3', () {
      expect(randomValue, isNotNull);
      expect(otherValue, isNotNull);
    });

    test('dummy test 4', () {
      expect(randomValue, isNotNull);
      expect(otherValue, isNotNull);
    });
  });
}
