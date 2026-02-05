import 'package:coverde/src/features/comparison/comparison.dart';
import 'package:test/test.dart';

void main() {
  group('$NumericComparison', () {
    group('fromDescription', () {
      test(
          '| throws '
          '$NumericComparisonFromDescriptionInvalidIdentifierFailure '
          'when no separator between identifier and argument is provided', () {
        expect(
          () => NumericComparison.fromDescription('invalid', int.parse),
          throwsA(
            isA<NumericComparisonFromDescriptionInvalidIdentifierFailure>(),
          ),
        );
      });

      test(
          '| throws '
          '$NumericComparisonFromDescriptionInvalidIdentifierFailure '
          'when only the separator between identifier and argument '
          'is provided', () {
        expect(
          () => NumericComparison.fromDescription('|', int.parse),
          throwsA(
            isA<NumericComparisonFromDescriptionInvalidIdentifierFailure>(),
          ),
        );
      });

      test(
          '| throws '
          '$NumericComparisonFromDescriptionInvalidIdentifierFailure '
          'when no description is provided', () {
        expect(
          () => NumericComparison.fromDescription('', int.parse),
          throwsA(
            isA<NumericComparisonFromDescriptionInvalidIdentifierFailure>(),
          ),
        );
      });

      group('identifier: ${EqualsNumericComparison.identifier}', () {
        test('| returns $EqualsNumericComparison', () {
          final comparison = NumericComparison.fromDescription(
            '${EqualsNumericComparison.identifier}|10',
            int.parse,
          );
          expect(
            comparison,
            const EqualsNumericComparison(reference: 10),
          );
        });

        test(
            '| throws '
            '$NumericComparisonFromDescriptionInvalidRawReferenceFailure '
            'when invalid raw reference', () {
          expect(
            () => NumericComparison.fromDescription(
              '${EqualsNumericComparison.identifier}|invalid',
              int.parse,
            ),
            throwsA(
              isA<NumericComparisonFromDescriptionInvalidRawReferenceFailure>(),
            ),
          );
        });
      });

      group('identifier: ${NotEqualToNumericComparison.identifier}', () {
        test('| returns $NotEqualToNumericComparison', () {
          final comparison = NumericComparison.fromDescription(
            '${NotEqualToNumericComparison.identifier}|10',
            int.parse,
          );
          expect(
            comparison,
            const NotEqualToNumericComparison(reference: 10),
          );
        });

        test(
            '| throws '
            '$NumericComparisonFromDescriptionInvalidRawReferenceFailure '
            'when invalid raw reference', () {
          expect(
            () => NumericComparison.fromDescription(
              '${NotEqualToNumericComparison.identifier}|invalid',
              int.parse,
            ),
            throwsA(
              isA<NumericComparisonFromDescriptionInvalidRawReferenceFailure>(),
            ),
          );
        });
      });

      group('identifier: ${GreaterThanNumericComparison.identifier}', () {
        test('| returns $GreaterThanNumericComparison', () {
          final comparison = NumericComparison.fromDescription(
            '${GreaterThanNumericComparison.identifier}|10',
            int.parse,
          );
          expect(
            comparison,
            const GreaterThanNumericComparison(reference: 10),
          );
        });

        test(
            '| throws '
            '$NumericComparisonFromDescriptionInvalidRawReferenceFailure '
            'when invalid raw reference', () {
          expect(
            () => NumericComparison.fromDescription(
              '${GreaterThanNumericComparison.identifier}|invalid',
              int.parse,
            ),
            throwsA(
              isA<NumericComparisonFromDescriptionInvalidRawReferenceFailure>(),
            ),
          );
        });
      });

      group('identifier: ${GreaterThanOrEqualToNumericComparison.identifier}',
          () {
        test('| returns $GreaterThanOrEqualToNumericComparison', () {
          final comparison = NumericComparison.fromDescription(
            '${GreaterThanOrEqualToNumericComparison.identifier}|10',
            int.parse,
          );
          expect(
            comparison,
            const GreaterThanOrEqualToNumericComparison(reference: 10),
          );
        });

        test(
            '| throws '
            '$NumericComparisonFromDescriptionInvalidRawReferenceFailure '
            'when invalid raw reference', () {
          expect(
            () => NumericComparison.fromDescription(
              '${GreaterThanOrEqualToNumericComparison.identifier}|invalid',
              int.parse,
            ),
            throwsA(
              isA<NumericComparisonFromDescriptionInvalidRawReferenceFailure>(),
            ),
          );
        });
      });

      group('identifier: ${LessThanNumericComparison.identifier}', () {
        test('| returns $LessThanNumericComparison', () {
          final comparison = NumericComparison.fromDescription(
            '${LessThanNumericComparison.identifier}|10',
            int.parse,
          );
          expect(
            comparison,
            const LessThanNumericComparison(reference: 10),
          );
        });

        test(
            '| throws '
            '$NumericComparisonFromDescriptionInvalidRawReferenceFailure '
            'when invalid raw reference', () {
          expect(
            () => NumericComparison.fromDescription(
              '${LessThanNumericComparison.identifier}|invalid',
              int.parse,
            ),
            throwsA(
              isA<NumericComparisonFromDescriptionInvalidRawReferenceFailure>(),
            ),
          );
        });
      });

      group('identifier: ${LessThanOrEqualToNumericComparison.identifier}', () {
        test('| returns $LessThanOrEqualToNumericComparison', () {
          final comparison = NumericComparison.fromDescription(
            '${LessThanOrEqualToNumericComparison.identifier}|10',
            int.parse,
          );
          expect(
            comparison,
            const LessThanOrEqualToNumericComparison(reference: 10),
          );
        });

        test(
            '| throws '
            '$NumericComparisonFromDescriptionInvalidRawReferenceFailure '
            'when invalid raw reference', () {
          expect(
            () => NumericComparison.fromDescription(
              '${LessThanOrEqualToNumericComparison.identifier}|invalid',
              int.parse,
            ),
            throwsA(
              isA<NumericComparisonFromDescriptionInvalidRawReferenceFailure>(),
            ),
          );
        });
      });

      group('identifier: ${RangeNumericComparison.identifier}', () {
        group('(lower bound exclusive, upper bound exclusive)', () {
          test('| returns $RangeNumericComparison', () {
            final comparison = NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|(10,20)',
              int.parse,
            );
            expect(
              comparison,
              const RangeNumericComparison(
                lowerReference: 10,
                upperReference: 20,
                lowerInclusive: false,
                upperInclusive: false,
              ),
            );
          });
        });

        group('(lower bound exclusive, upper bound inclusive)', () {
          test('| returns $RangeNumericComparison', () {
            final comparison = NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|(10,20]',
              int.parse,
            );
            expect(
              comparison,
              const RangeNumericComparison(
                lowerReference: 10,
                upperReference: 20,
                lowerInclusive: false,
                upperInclusive: true,
              ),
            );
          });
        });

        group('(lower bound inclusive, upper bound exclusive)', () {
          test('| returns $RangeNumericComparison', () {
            final comparison = NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|[10,20)',
              int.parse,
            );
            expect(
              comparison,
              const RangeNumericComparison(
                lowerReference: 10,
                upperReference: 20,
                lowerInclusive: true,
                upperInclusive: false,
              ),
            );
          });
        });

        group('(lower bound inclusive, upper bound inclusive)', () {
          test('| returns $RangeNumericComparison', () {
            final comparison = NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|[10,20]',
              int.parse,
            );
            expect(
              comparison,
              const RangeNumericComparison(
                lowerReference: 10,
                upperReference: 20,
                lowerInclusive: true,
                upperInclusive: true,
              ),
            );
          });
        });

        test(
            '| throws '
            // Long class name
            // ignore: lines_longer_than_80_chars
            '$NumericComparisonFromDescriptionInvalidRangeBoundIndicatorFailure '
            'when no lower bound indicator is provided', () {
          expect(
            () => NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|10,20)',
              int.parse,
            ),
            throwsA(
              // Long class name
              // ignore: lines_longer_than_80_chars
              isA<NumericComparisonFromDescriptionInvalidRangeBoundIndicatorFailure>(),
            ),
          );
        });

        test(
            '| throws '
            // Long class name
            // ignore: lines_longer_than_80_chars
            '$NumericComparisonFromDescriptionInvalidRangeBoundIndicatorFailure '
            'when an invalid lower bound indicator is provided', () {
          expect(
            () => NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|x10,20)',
              int.parse,
            ),
            throwsA(
              // Long class name
              // ignore: lines_longer_than_80_chars
              isA<NumericComparisonFromDescriptionInvalidRangeBoundIndicatorFailure>(),
            ),
          );
        });

        test(
            '| throws '
            // Long class name
            // ignore: lines_longer_than_80_chars
            '$NumericComparisonFromDescriptionInvalidRangeBoundIndicatorFailure '
            'when no upper bound indicator is provided', () {
          expect(
            () => NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|(10,20',
              int.parse,
            ),
            throwsA(
              // Long class name
              // ignore: lines_longer_than_80_chars
              isA<NumericComparisonFromDescriptionInvalidRangeBoundIndicatorFailure>(),
            ),
          );
        });

        test(
            '| throws '
            // Long class name
            // ignore: lines_longer_than_80_chars
            '$NumericComparisonFromDescriptionInvalidRangeBoundIndicatorFailure '
            'when an invalid upper bound indicator is provided', () {
          expect(
            () => NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|(10,20x',
              int.parse,
            ),
            throwsA(
              // Long class name
              // ignore: lines_longer_than_80_chars
              isA<NumericComparisonFromDescriptionInvalidRangeBoundIndicatorFailure>(),
            ),
          );
        });

        test(
            '| throws '
            '$NumericComparisonFromDescriptionInvalidRawReferenceFailure '
            'when no lower bound is provided', () {
          expect(
            () => NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|(,20)',
              int.parse,
            ),
            throwsA(
              isA<NumericComparisonFromDescriptionInvalidRawReferenceFailure>(),
            ),
          );
        });

        test(
            '| throws '
            '$NumericComparisonFromDescriptionInvalidRawReferenceFailure '
            'when no upper bound is provided', () {
          expect(
            () => NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|(10,)',
              int.parse,
            ),
            throwsA(
              isA<NumericComparisonFromDescriptionInvalidRawReferenceFailure>(),
            ),
          );
        });

        test(
            '| throws '
            '$NumericComparisonFromDescriptionInvalidRawReferenceFailure '
            'when no lower nor upper bound is provided', () {
          expect(
            () => NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|(,)',
              int.parse,
            ),
            throwsA(
              isA<NumericComparisonFromDescriptionInvalidRawReferenceFailure>(),
            ),
          );
        });

        test(
            '| throws '
            '$NumericComparisonFromDescriptionInvalidRawReferenceFailure '
            'when only bound indicators are provided', () {
          expect(
            () => NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|()',
              int.parse,
            ),
            throwsA(
              isA<NumericComparisonFromDescriptionInvalidRawReferenceFailure>(),
            ),
          );
        });

        test(
            '| throws '
            '$NumericComparisonFromDescriptionInvalidRawReferenceFailure '
            'when only bounds separator is provided', () {
          expect(
            () => NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|,',
              int.parse,
            ),
            throwsA(
              isA<NumericComparisonFromDescriptionInvalidRawReferenceFailure>(),
            ),
          );
        });

        test(
            '| throws '
            '$NumericComparisonFromDescriptionInvalidRawReferenceFailure '
            'when no argument is provided', () {
          expect(
            () => NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|',
              int.parse,
            ),
            throwsA(
              isA<NumericComparisonFromDescriptionInvalidRawReferenceFailure>(),
            ),
          );
        });

        test(
            '| throws '
            '$NumericComparisonFromDescriptionInvalidRawReferenceFailure '
            'when only the identifier is provided', () {
          expect(
            () => NumericComparison.fromDescription(
              RangeNumericComparison.identifier,
              int.parse,
            ),
            throwsA(
              isA<NumericComparisonFromDescriptionInvalidRawReferenceFailure>(),
            ),
          );
        });

        test(
            '| throws '
            '$NumericComparisonFromDescriptionInvalidRawReferenceFailure '
            'when multiple reference values are provided', () {
          expect(
            () => NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|(10,20,30)',
              int.parse,
            ),
            throwsA(
              isA<NumericComparisonFromDescriptionInvalidRawReferenceFailure>(),
            ),
          );
        });

        test(
            '| throws '
            '$NumericComparisonFromDescriptionInvalidRangeBoundsOrderFailure '
            'when the lower bound is greater than to the upper bound', () {
          expect(
            () => NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|(20,10)',
              int.parse,
            ),
            throwsA(
              // Long class name
              // ignore: lines_longer_than_80_chars
              isA<NumericComparisonFromDescriptionInvalidRangeBoundsOrderFailure>(),
            ),
          );
        });

        test(
            '| throws '
            '$NumericComparisonFromDescriptionInvalidRangeBoundsOrderFailure '
            'when the lower bound is equal to the upper bound', () {
          expect(
            () => NumericComparison.fromDescription(
              '${RangeNumericComparison.identifier}|(20,20)',
              int.parse,
            ),
            throwsA(
              // Long class name
              // ignore: lines_longer_than_80_chars
              isA<NumericComparisonFromDescriptionInvalidRangeBoundsOrderFailure>(),
            ),
          );
        });
      });

      test(
          '| throws $NumericComparisonFromDescriptionInvalidIdentifierFailure '
          'when an invalid identifier is provided', () {
        expect(
          () => NumericComparison.fromDescription('invalid|10', int.parse),
          throwsA(
            isA<NumericComparisonFromDescriptionInvalidIdentifierFailure>(),
          ),
        );
      });
    });

    group('$EqualsNumericComparison', () {
      group('describe', () {
        test('| returns description', () {
          const comparison = EqualsNumericComparison(reference: 10);
          expect(comparison.describe, 'eq|10');
        });
      });

      group('matches', () {
        test('| returns true when the value is equal to the reference', () {
          const comparison = EqualsNumericComparison(reference: 10);
          expect(comparison.matches(10), isTrue);
          expect(comparison.matches(9), isFalse);
        });
      });

      group('== & hashCode', () {
        test('| verifies equality and hash code resolution', () {
          const subject = EqualsNumericComparison(reference: 10);
          const same = EqualsNumericComparison(reference: 10);
          const other = EqualsNumericComparison(reference: 9);
          expect(subject, same);
          expect(subject, isNot(other));
          expect(subject.hashCode, same.hashCode);
          expect(subject.hashCode, isNot(other.hashCode));
        });
      });
    });

    group('$NotEqualToNumericComparison', () {
      group('describe', () {
        test('| returns description', () {
          const comparison = NotEqualToNumericComparison(reference: 10);
          expect(comparison.describe, 'neq|10');
        });
      });

      group('matches', () {
        test('| verifies value matching the reference', () {
          const comparison = NotEqualToNumericComparison(reference: 10);
          expect(comparison.matches(9), isTrue);
          expect(comparison.matches(10), isFalse);
        });
      });

      group('== & hashCode', () {
        test('| verifies equality and hash code resolution', () {
          const subject = NotEqualToNumericComparison(reference: 10);
          const same = NotEqualToNumericComparison(reference: 10);
          const other = NotEqualToNumericComparison(reference: 9);
          expect(subject, same);
          expect(subject, isNot(other));
          expect(subject.hashCode, same.hashCode);
          expect(subject.hashCode, isNot(other.hashCode));
        });
      });
    });

    group('$GreaterThanNumericComparison', () {
      group('describe', () {
        test('| returns description', () {
          const comparison = GreaterThanNumericComparison(reference: 10);
          expect(comparison.describe, 'gt|10');
        });
      });

      group('matches', () {
        test('| verifies value matching the reference', () {
          const comparison = GreaterThanNumericComparison(reference: 10);
          expect(comparison.matches(11), isTrue);
          expect(comparison.matches(10), isFalse);
          expect(comparison.matches(9), isFalse);
        });
      });

      group('== & hashCode', () {
        test('| verifies equality and hash code resolution', () {
          const subject = GreaterThanNumericComparison(reference: 10);
          const same = GreaterThanNumericComparison(reference: 10);
          const other = GreaterThanNumericComparison(reference: 9);
          expect(subject, same);
          expect(subject, isNot(other));
          expect(subject.hashCode, same.hashCode);
          expect(subject.hashCode, isNot(other.hashCode));
        });
      });
    });

    group('$GreaterThanOrEqualToNumericComparison', () {
      group('describe', () {
        test('| returns description', () {
          const comparison =
              GreaterThanOrEqualToNumericComparison(reference: 10);
          expect(comparison.describe, 'gte|10');
        });
      });

      group('matches', () {
        test('| verifies value matching the reference', () {
          const comparison =
              GreaterThanOrEqualToNumericComparison(reference: 10);
          expect(comparison.matches(11), isTrue);
          expect(comparison.matches(10), isTrue);
          expect(comparison.matches(9), isFalse);
        });
      });

      group('== & hashCode', () {
        test('| verifies equality and hash code resolution', () {
          const subject = GreaterThanOrEqualToNumericComparison(reference: 10);
          const same = GreaterThanOrEqualToNumericComparison(reference: 10);
          const other = GreaterThanOrEqualToNumericComparison(reference: 9);
          expect(subject, same);
          expect(subject, isNot(other));
          expect(subject.hashCode, same.hashCode);
          expect(subject.hashCode, isNot(other.hashCode));
        });
      });
    });

    group('$LessThanNumericComparison', () {
      group('describe', () {
        test('| returns description', () {
          const comparison = LessThanNumericComparison(reference: 10);
          expect(comparison.describe, 'lt|10');
        });
      });

      group('matches', () {
        test('| verifies value matching the reference', () {
          const comparison = LessThanNumericComparison(reference: 10);
          expect(comparison.matches(9), isTrue);
          expect(comparison.matches(10), isFalse);
          expect(comparison.matches(11), isFalse);
        });
      });

      group('== & hashCode', () {
        test('| verifies equality and hash code resolution', () {
          const subject = LessThanNumericComparison(reference: 10);
          const same = LessThanNumericComparison(reference: 10);
          const other = LessThanNumericComparison(reference: 9);
          expect(subject, same);
          expect(subject, isNot(other));
          expect(subject.hashCode, same.hashCode);
          expect(subject.hashCode, isNot(other.hashCode));
        });
      });
    });

    group('$LessThanOrEqualToNumericComparison', () {
      group('describe', () {
        test('| returns description', () {
          const comparison = LessThanOrEqualToNumericComparison(reference: 10);
          expect(comparison.describe, 'lte|10');
        });
      });

      group('matches', () {
        test('| verifies value matching the reference', () {
          const comparison = LessThanOrEqualToNumericComparison(reference: 10);
          expect(comparison.matches(9), isTrue);
          expect(comparison.matches(10), isTrue);
          expect(comparison.matches(11), isFalse);
        });
      });

      group('== & hashCode', () {
        test('| verifies equality and hash code resolution', () {
          const subject = LessThanOrEqualToNumericComparison(reference: 10);
          const same = LessThanOrEqualToNumericComparison(reference: 10);
          const other = LessThanOrEqualToNumericComparison(reference: 9);
          expect(subject, same);
          expect(subject, isNot(other));
          expect(subject.hashCode, same.hashCode);
          expect(subject.hashCode, isNot(other.hashCode));
        });
      });
    });

    group('$RangeNumericComparison', () {
      group('describe', () {
        test('| returns description', () {
          const caseOpenOpen = RangeNumericComparison(
            lowerReference: 10,
            upperReference: 20,
            lowerInclusive: false,
            upperInclusive: false,
          );
          expect(caseOpenOpen.describe, 'in|(10,20)');
          const caseOpenClosed = RangeNumericComparison(
            lowerReference: 10,
            upperReference: 20,
            lowerInclusive: false,
            upperInclusive: true,
          );
          expect(caseOpenClosed.describe, 'in|(10,20]');
          const caseClosedOpen = RangeNumericComparison(
            lowerReference: 10,
            upperReference: 20,
            lowerInclusive: true,
            upperInclusive: false,
          );
          expect(caseClosedOpen.describe, 'in|[10,20)');
          const caseClosedClosed = RangeNumericComparison(
            lowerReference: 10,
            upperReference: 20,
            lowerInclusive: true,
            upperInclusive: true,
          );
          expect(caseClosedClosed.describe, 'in|[10,20]');
        });
      });

      group('matches', () {
        test('| verifies value matching the reference', () {
          const caseOpenOpen = RangeNumericComparison(
            lowerReference: 10,
            upperReference: 20,
            lowerInclusive: false,
            upperInclusive: false,
          );
          expect(caseOpenOpen.matches(9), isFalse);
          expect(caseOpenOpen.matches(10), isFalse);
          expect(caseOpenOpen.matches(11), isTrue);
          expect(caseOpenOpen.matches(19), isTrue);
          expect(caseOpenOpen.matches(20), isFalse);
          expect(caseOpenOpen.matches(21), isFalse);
          const caseOpenClosed = RangeNumericComparison(
            lowerReference: 10,
            upperReference: 20,
            lowerInclusive: false,
            upperInclusive: true,
          );
          expect(caseOpenClosed.matches(9), isFalse);
          expect(caseOpenClosed.matches(10), isFalse);
          expect(caseOpenClosed.matches(11), isTrue);
          expect(caseOpenClosed.matches(19), isTrue);
          expect(caseOpenClosed.matches(20), isTrue);
          expect(caseOpenClosed.matches(21), isFalse);
          const caseClosedOpen = RangeNumericComparison(
            lowerReference: 10,
            upperReference: 20,
            lowerInclusive: true,
            upperInclusive: false,
          );
          expect(caseClosedOpen.matches(9), isFalse);
          expect(caseClosedOpen.matches(10), isTrue);
          expect(caseClosedOpen.matches(11), isTrue);
          expect(caseClosedOpen.matches(19), isTrue);
          expect(caseClosedOpen.matches(20), isFalse);
          expect(caseClosedOpen.matches(21), isFalse);
          const caseClosedClosed = RangeNumericComparison(
            lowerReference: 10,
            upperReference: 20,
            lowerInclusive: true,
            upperInclusive: true,
          );
          expect(caseClosedClosed.matches(9), isFalse);
          expect(caseClosedClosed.matches(10), isTrue);
          expect(caseClosedClosed.matches(11), isTrue);
          expect(caseClosedClosed.matches(19), isTrue);
          expect(caseClosedClosed.matches(20), isTrue);
          expect(caseClosedClosed.matches(21), isFalse);
        });
      });

      group('== & hashCode', () {
        test('| verifies equality and hash code resolution', () {
          const subject = RangeNumericComparison(
            lowerReference: 10,
            upperReference: 20,
            lowerInclusive: false,
            upperInclusive: false,
          );
          const same = RangeNumericComparison(
            lowerReference: 10,
            upperReference: 20,
            lowerInclusive: false,
            upperInclusive: false,
          );
          const other1 = RangeNumericComparison(
            lowerReference: 11,
            upperReference: 20,
            lowerInclusive: false,
            upperInclusive: false,
          );
          const other2 = RangeNumericComparison(
            lowerReference: 10,
            upperReference: 19,
            lowerInclusive: false,
            upperInclusive: false,
          );
          const other3 = RangeNumericComparison(
            lowerReference: 10,
            upperReference: 20,
            lowerInclusive: true,
            upperInclusive: false,
          );
          const other4 = RangeNumericComparison(
            lowerReference: 10,
            upperReference: 20,
            lowerInclusive: false,
            upperInclusive: true,
          );
          expect(subject, same);
          expect(subject, isNot(other1));
          expect(subject, isNot(other2));
          expect(subject, isNot(other3));
          expect(subject, isNot(other4));
          expect(subject.hashCode, same.hashCode);
          expect(subject.hashCode, isNot(other1.hashCode));
          expect(subject.hashCode, isNot(other2.hashCode));
          expect(subject.hashCode, isNot(other3.hashCode));
          expect(subject.hashCode, isNot(other4.hashCode));
        });
      });
    });
  });
}
