import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

void main() {
  int? randomValue;

  setUp(() {
    randomValue = math.Random().nextInt(100);
  });

  tearDown(() {
    randomValue = null;
  });

  testWidgets('dummy test 1', (tester) async {
    expect(randomValue, isNotNull);
  });

  testWidgets('dummy test 2', (tester) async {
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

    testWidgets('dummy test 3', (tester) async {
      expect(randomValue, isNotNull);
      expect(otherValue, isNotNull);
    });

    testWidgets('dummy test 4', (tester) async {
      expect(randomValue, isNotNull);
      expect(otherValue, isNotNull);
    });
  });
}
