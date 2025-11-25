import 'package:coverde/src/entities/cov_line.dart';
import 'package:test/test.dart';

void main() {
  group('$CovLine', () {
    test(
      '| supports value comparison',
      () {
        const lineNumber = 10;
        const hitsNumber = 24;
        final sourceFileCovData = CovLine(
          lineNumber: lineNumber,
          hitsNumber: hitsNumber,
          checksum: null,
        );
        final sameSourceFileCovData = CovLine(
          lineNumber: lineNumber,
          hitsNumber: hitsNumber,
          checksum: null,
        );

        final valueComparisonResult =
            sourceFileCovData == sameSourceFileCovData;
        final hashComparisonResult =
            sourceFileCovData.hashCode == sameSourceFileCovData.hashCode;

        expect(valueComparisonResult, isTrue);
        expect(hashComparisonResult, isTrue);
      },
    );

    for (final hasLineDataTag in [true, false]) {
      test(
        '| parses valid string representation '
        '${hasLineDataTag ? 'with' : 'without'} line data tag',
        () async {
          const lineNumber = 43;
          const hitsNumber = 64;
          final covLineString =
              '${hasLineDataTag ? 'DA:' : ''}$lineNumber,$hitsNumber';
          final expectedCovLine = CovLine(
            lineNumber: lineNumber,
            hitsNumber: hitsNumber,
            checksum: null,
          );

          final result = CovLine.parse(covLineString);

          expect(result, expectedCovLine);
        },
      );
    }
  });
}
