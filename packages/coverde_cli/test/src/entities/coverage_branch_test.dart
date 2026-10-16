// Non-const constructors for testing purposes.
// ignore_for_file: prefer_const_constructors
// Non-const list literals for the same reason.
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:coverde/src/entities/coverage_branch.dart';
import 'package:test/test.dart';

void main() {
  group('$CoverageBranch', () {
    test('stores a taken count and a branch that was not executed', () {
      final taken = CoverageBranch(line: 10, block: 1, branch: 0, taken: 3);
      final skipped = CoverageBranch(
        line: 10,
        block: 1,
        branch: 1,
        taken: null,
      );

      expect(taken.line, 10);
      expect(taken.block, 1);
      expect(taken.branch, 0);
      expect(taken.taken, 3);
      expect(skipped.taken, isNull);
    });

    test('equates branches with the same identity', () {
      final subject = CoverageBranch(line: 10, block: 1, branch: 0, taken: 3);
      final same = CoverageBranch(line: 10, block: 1, branch: 0, taken: 3);

      expect(subject == subject, isTrue);
      expect(subject, same);
      expect(subject.hashCode, same.hashCode);
      expect(
        subject,
        isNot(CoverageBranch(line: 11, block: 1, branch: 0, taken: 3)),
      );
      expect(
        subject,
        isNot(CoverageBranch(line: 10, block: 2, branch: 0, taken: 3)),
      );
      expect(
        subject,
        isNot(CoverageBranch(line: 10, block: 1, branch: 1, taken: 3)),
      );
      expect(
        subject,
        isNot(CoverageBranch(line: 10, block: 1, branch: 0, taken: null)),
      );
      expect(
        subject,
        isNot(CoverageBranch(line: 10, block: 1, branch: 0, taken: 0)),
      );
      expect(subject == Object(), isFalse);
    });
  });

  group('$CoverageBranches', () {
    test('keeps the branch list in the given order', () {
      final first = CoverageBranch(line: 2, block: 0, branch: 0, taken: 1);
      final second = CoverageBranch(line: 1, block: 0, branch: 0, taken: null);
      final group = CoverageBranches(
        hit: 1,
        found: 2,
        branches: [first, second],
      );

      expect(group.hit, 1);
      expect(group.found, 2);
      expect(group.branches, [first, second]);
      expect(() => group.branches.add(first), throwsUnsupportedError);
    });

    test('copies the branch list', () {
      final branch = CoverageBranch(line: 1, block: 0, branch: 0, taken: 1);
      final input = [branch];
      final group = CoverageBranches(hit: 1, found: 1, branches: input);

      input.clear();

      expect(group.branches, [branch]);
    });

    test('equates groups with the same counts and branches', () {
      final branch = CoverageBranch(line: 1, block: 0, branch: 0, taken: 1);
      final subject = CoverageBranches(hit: 1, found: 1, branches: [branch]);
      final same = CoverageBranches(hit: 1, found: 1, branches: [branch]);

      expect(subject == subject, isTrue);
      expect(subject, same);
      expect(subject.hashCode, same.hashCode);
      expect(
        subject,
        isNot(CoverageBranches(hit: 0, found: 1, branches: [branch])),
      );
      expect(
        subject,
        isNot(CoverageBranches(hit: 1, found: 2, branches: [branch])),
      );
      expect(
        subject,
        isNot(
          CoverageBranches(
            hit: 1,
            found: 1,
            branches: [CoverageBranch(line: 1, block: 0, branch: 1, taken: 1)],
          ),
        ),
      );
      expect(subject == Object(), isFalse);
    });
  });
}
