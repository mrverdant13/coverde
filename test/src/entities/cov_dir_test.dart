import 'package:coverde/src/entities/cov_dir.dart';
import 'package:coverde/src/entities/cov_file.dart';
import 'package:coverde/src/entities/cov_line.dart';
import 'package:coverde/src/utils/path.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  test(
    '''

GIVEN two directory coverage data instances
├─ THAT hold the same data
WHEN they are compared with each other
THEN a positive result should be returned
''',
    () {
      const sourcePath = 'path/to/source/folder/';
      final nestedCovElements = [
        CovDir(
          source: Directory(path.join(sourcePath, 'dir')),
          elements: const [],
        ),
        CovFile(
          source: File(
            path.join(sourcePath, 'file.extension'),
          ),
          raw: '',
          covLines: const [],
        ),
      ];
      final covDir = CovDir(
        source: Directory(sourcePath),
        elements: nestedCovElements,
      );

      final sameCovDir = CovDir(
        source: Directory(sourcePath),
        elements: nestedCovElements,
      );

      // ACT
      final valueComparisonResult = covDir == sameCovDir;
      final hashComparisonResult = covDir.hashCode == sameCovDir.hashCode;

      // ASSERT
      expect(valueComparisonResult, isTrue);
      expect(hashComparisonResult, isTrue);
    },
  );

  {
    // ARRANGE
    final covFiles = [
      CovFile(
        source: File(
          'test/dir_1/file_1.1.ext',
        ),
        raw: '',
        covLines: [
          CovLine(lineNumber: 1, hitsNumber: 1, checksum: null),
        ],
      ),
      CovFile(
        source: File(
          'test/dir_1/file_1.2.ext',
        ),
        raw: '',
        covLines: [
          CovLine(lineNumber: 1, hitsNumber: 1, checksum: null),
        ],
      ),
      CovFile(
        source: File(
          'test/dir_2/dir_2_1/dir_2_1_1/file_2_1_1.1.ext',
        ),
        raw: '',
        covLines: [
          CovLine(lineNumber: 1, hitsNumber: 1, checksum: null),
        ],
      ),
      CovFile(
        source: File(
          'test/dir_2/dir_2_1/dir_2_1_1/dir_2_1_1_1/dir_2_1_1_1_1/file_2_1_1_1_1.1.ext',
        ),
        raw: '',
        covLines: [
          CovLine(lineNumber: 1, hitsNumber: 1, checksum: null),
        ],
      ),
    ];
    final tree = CovDir(
      source: Directory('test/'),
      elements: [
        CovDir(
          source: Directory('test/dir_1/'),
          elements: [
            CovFile(
              source: File('test/dir_1/file_1.1.ext'),
              raw: '',
              covLines: [
                CovLine(lineNumber: 1, hitsNumber: 1, checksum: null),
              ],
            ),
            CovFile(
              source: File('test/dir_1/file_1.2.ext'),
              raw: '',
              covLines: [
                CovLine(lineNumber: 1, hitsNumber: 1, checksum: null),
              ],
            ),
          ],
        ),
        CovDir(
          source: Directory('test/dir_2/dir_2_1/dir_2_1_1'),
          elements: [
            CovDir(
              source: Directory(
                'test/dir_2/dir_2_1/dir_2_1_1/dir_2_1_1_1/dir_2_1_1_1_1/',
              ),
              elements: [
                CovFile(
                  source: File(
                    'test/dir_2/dir_2_1/dir_2_1_1/dir_2_1_1_1/dir_2_1_1_1_1/file_2_1_1_1_1.1.ext',
                  ),
                  raw: '',
                  covLines: [
                    CovLine(lineNumber: 1, hitsNumber: 1, checksum: null),
                  ],
                ),
              ],
            ),
            CovFile(
              source: File('test/dir_2/dir_2_1/dir_2_1_1/file_2_1_1.1.ext'),
              raw: '',
              covLines: [
                CovLine(lineNumber: 1, hitsNumber: 1, checksum: null),
              ],
            ),
          ],
        ),
      ],
    );

    group(
      '''
    
GIVEN a collection of coverage file data
├─ THAT is organized as follows:
│   test/ (dir)
│   ├─ dir_1/ (dir)
│   │  ├─ file_1.1.ext (file)
│   │  ├─ file_1.2.ext (file)
│   ├─ dir_2/ (dir)
│   │  ├─ dir_2_1/ (dir)
│   │  │  ├─ dir_2_1_1/ (dir)
│   │  │  │  ├─ file_2_1_1.1.ext (file)
│   │  │  │  ├─ dir_2_1_1_1/ (dir)
│   │  │  │  │  ├─ dir_2_1_1_1_1/ (dir)
│   │  │  │  │  │  ├─ file_2_1_1_1_1.1.ext (file)''',
      () {
        test(
          '''

WHEN they are dispatched to be arranged according to their source paths
THEN a tree sctructure of coverage data elements is returned
''',
          () {
            // ACT
            final result = CovDir.tree(covFiles: covFiles);

            // ASSERT
            expect(result, tree);
          },
        );

        test(
          '''

AND a base folder path
├─ THAT does not contains any of the coverage file data
WHEN they are dispatched to be arranged according to their source paths
THEN an empty coverage folder should be returned
''',
          () {
            // ARRANGE
            const baseDirPath = 'other/dir/';
            final expectedSubtree = CovDir(
              source: Directory(baseDirPath),
              elements: const [],
            );

            // ACT
            final result = CovDir.subtree(
              baseDirPath: baseDirPath,
              coveredFiles: covFiles,
            );

            // ASSERT
            expect(result, expectedSubtree);
          },
        );
      },
    );

    test(
      '''

GIVEN a tree structure of covered elements
WHEN its string representation is requested
THEN a formatted string should be returned
''',
      () {
        // ARRANGE
        const expectedTreeString = '''
Node: test/ (100.00% - 4/4)
├─ Node: test/dir_1/ (100.00% - 2/2)
│  ├─ SF: test/dir_1/file_1.1.ext (100.00% - 1/1)
│  ├─ SF: test/dir_1/file_1.2.ext (100.00% - 1/1)
│  
├─ Node: test/dir_2/dir_2_1/dir_2_1_1 (100.00% - 2/2)
│  ├─ Node: test/dir_2/dir_2_1/dir_2_1_1/dir_2_1_1_1/dir_2_1_1_1_1/ (100.00% - 1/1)
│  │  ├─ SF: test/dir_2/dir_2_1/dir_2_1_1/dir_2_1_1_1/dir_2_1_1_1_1/file_2_1_1_1_1.1.ext (100.00% - 1/1)
│  │  
│  ├─ SF: test/dir_2/dir_2_1/dir_2_1_1/file_2_1_1.1.ext (100.00% - 1/1)
│  
''';

        // ACT
        final result = tree.toString();

        // ASSERT
        expect(result, expectedTreeString);
      },
    );
  }
}
