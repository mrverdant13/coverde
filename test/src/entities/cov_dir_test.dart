import 'dart:io';

import 'package:cov_utils/src/entities/cov_dir.dart';
import 'package:cov_utils/src/entities/cov_file.dart';
import 'package:cov_utils/src/entities/cov_line.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

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
          source: Directory(p.join(sourcePath, 'dir')),
          elements: const [],
        ),
        CovFile(
          source: File(
            p.join(sourcePath, 'file.extension'),
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
        source: Directory(sourcePath.replaceAll('/', r'\')),
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

  test(
    '''

GIVEN a collection of coverage file data
THAT are organized this way:
  test/ (dir)
  ├─ dir_1/ (dir)
  │  ├─ file_1.1.ext (file)
  │  ├─ file_1.2.ext (file)
  ├─ dir_2/ (dir)
  │  ├─ dir_2_1/ (dir)
  │  │  ├─ dir_2_1_1/ (dir)
  │  │  │  ├─ file_2_1_1.1.ext (file)
  │  │  │  ├─ dir_2_1_1_1/ (dir)
  │  │  │  │  ├─ dir_2_1_1_1_1/ (dir)
  │  │  │  │  │  ├─ file_2_1_1_1_1.1.ext (file)
WHEN they are dispatched to be arranged according to their source paths
THEN a tree sctructure of coverage data elements is returned
''',
    () {
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
      final expectedTree = CovDir(
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

      // ACT
      final result = CovDir.tree(covFiles: covFiles);

      // ASSERT
      expect(result, expectedTree);
    },
  );
}
