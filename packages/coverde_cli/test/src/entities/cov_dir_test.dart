import 'dart:convert';

import 'package:coverde/src/entities/cov_dir.dart';
import 'package:coverde/src/entities/cov_file.dart';
import 'package:coverde/src/entities/cov_line.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:universal_io/io.dart';

void main() {
  group('$CovDir', () {
    test(
      '| supports value comparison',
      () {
        final sourcePath = path.joinAll(['path', 'to', 'source', 'folder']);
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
            path.joinAll([
              'test',
              'dir_1',
              'file_1.1.ext',
            ]),
          ),
          raw: '',
          covLines: [
            CovLine(lineNumber: 1, hitsNumber: 1, checksum: null),
          ],
        ),
        CovFile(
          source: File(
            path.joinAll([
              'test',
              'dir_1',
              'file_1.2.ext',
            ]),
          ),
          raw: '',
          covLines: [
            CovLine(lineNumber: 1, hitsNumber: 1, checksum: null),
          ],
        ),
        CovFile(
          source: File(
            path.joinAll([
              'test',
              'dir_2',
              'dir_2_1',
              'dir_2_1_1',
              'file_2_1_1.1.ext',
            ]),
          ),
          raw: '',
          covLines: [
            CovLine(lineNumber: 1, hitsNumber: 1, checksum: null),
          ],
        ),
        CovFile(
          source: File(
            path.joinAll([
              'test',
              'dir_2',
              'dir_2_1',
              'dir_2_1_1',
              'dir_2_1_1_1',
              'dir_2_1_1_1_1',
              'file_2_1_1_1_1.1.ext',
            ]),
          ),
          raw: '',
          covLines: [
            CovLine(lineNumber: 1, hitsNumber: 1, checksum: null),
          ],
        ),
      ];
      final tree = CovDir(
        source: Directory(
          path.joinAll([
            'test',
          ]),
        ),
        elements: [
          CovDir(
            source: Directory(
              path.joinAll([
                'test',
                'dir_1',
              ]),
            ),
            elements: [
              CovFile(
                source: File(
                  path.joinAll([
                    'test',
                    'dir_1',
                    'file_1.1.ext',
                  ]),
                ),
                raw: '',
                covLines: [
                  CovLine(lineNumber: 1, hitsNumber: 1, checksum: null),
                ],
              ),
              CovFile(
                source: File(
                  path.joinAll([
                    'test',
                    'dir_1',
                    'file_1.2.ext',
                  ]),
                ),
                raw: '',
                covLines: [
                  CovLine(lineNumber: 1, hitsNumber: 1, checksum: null),
                ],
              ),
            ],
          ),
          CovDir(
            source: Directory(
              path.joinAll([
                'test',
                'dir_2',
                'dir_2_1',
                'dir_2_1_1',
              ]),
            ),
            elements: [
              CovDir(
                source: Directory(
                  path.joinAll([
                    'test',
                    'dir_2',
                    'dir_2_1',
                    'dir_2_1_1',
                    'dir_2_1_1_1',
                    'dir_2_1_1_1_1',
                  ]),
                ),
                elements: [
                  CovFile(
                    source: File(
                      path.joinAll([
                        'test',
                        'dir_2',
                        'dir_2_1',
                        'dir_2_1_1',
                        'dir_2_1_1_1',
                        'dir_2_1_1_1_1',
                        'file_2_1_1_1_1.1.ext',
                      ]),
                    ),
                    raw: '',
                    covLines: [
                      CovLine(lineNumber: 1, hitsNumber: 1, checksum: null),
                    ],
                  ),
                ],
              ),
              CovFile(
                source: File(
                  path.joinAll([
                    'test',
                    'dir_2',
                    'dir_2_1',
                    'dir_2_1_1',
                    'file_2_1_1.1.ext',
                  ]),
                ),
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
        'tree',
        () {
          test(
            '| creates coverage data tree structure',
            () {
              // ACT
              final result = CovDir.tree(covFiles: covFiles);

              // ASSERT
              expect(result, tree);
            },
          );

          test(
            '| returns empty coverage folder '
            'when base folder does not contain coverage file data',
            () {
              // ARRANGE
              final baseDirPath = path.joinAll([
                'other',
                'dir',
              ]);
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
        '| returns formatted string representation',
        () {
          // ARRANGE
          final expectedTreeString = '''
Node: ${path.joinAll([
                'test',
              ])} (100.00% - 4/4)
├─ Node: ${path.joinAll([
                'test',
                'dir_1',
              ])} (100.00% - 2/2)
│  ├─ SF: ${path.joinAll([
                'test',
                'dir_1',
                'file_1.1.ext',
              ])} (100.00% - 1/1)
│  ├─ SF: ${path.joinAll([
                'test',
                'dir_1',
                'file_1.2.ext',
              ])} (100.00% - 1/1)
│
├─ Node: ${path.joinAll([
                'test',
                'dir_2',
                'dir_2_1',
                'dir_2_1_1',
              ])} (100.00% - 2/2)
│  ├─ Node: ${path.joinAll([
                'test',
                'dir_2',
                'dir_2_1',
                'dir_2_1_1',
                'dir_2_1_1_1',
                'dir_2_1_1_1_1',
              ])} (100.00% - 1/1)
│  │  ├─ SF: ${path.joinAll([
                'test',
                'dir_2',
                'dir_2_1',
                'dir_2_1_1',
                'dir_2_1_1_1',
                'dir_2_1_1_1_1',
                'file_2_1_1_1_1.1.ext',
              ])} (100.00% - 1/1)
│  │
│  ├─ SF: ${path.joinAll([
                'test',
                'dir_2',
                'dir_2_1',
                'dir_2_1_1',
                'file_2_1_1.1.ext',
              ])} (100.00% - 1/1)
│
''';

          // ACT
          final result = tree.toString();

          // ASSERT
          const splitter = LineSplitter();
          expect(
            splitter.convert(result).map((line) => line.trim()),
            splitter.convert(expectedTreeString).map((line) => line.trim()),
          );
        },
      );
    }
  });
}
