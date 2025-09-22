import 'dart:math' as math;

num add(num a, num b) {
  return a + b;
}

num subtract(num a, num b) {
  return a - b;
}

num multiply(num a, num b) {
  return a * b;
}

num divide(num a, num b) {
  if (b == 0) {
    throw Exception('Division by zero');
  }
  return a / b;
}

num modulo(num a, num b) {
  if (b == 0) {
    throw Exception('Division by zero');
  }
  return a % b;
}

num power(num a, num b) {
  return math.pow(a, b);
}
