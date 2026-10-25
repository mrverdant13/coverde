import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// {@template coverde.coverage_branch}
/// Hit data for one branch.
/// {@endtemplate}
@immutable
final class CoverageBranch {
  /// {@macro coverde.coverage_branch}
  const CoverageBranch({
    required this.line,
    required this.block,
    required this.branch,
    required this.taken,
  });

  /// The 1-based line that contains this branch.
  final int line;

  /// The branch block number from `BRDA:`.
  final int block;

  /// The branch number within [block].
  final int branch;

  /// How many times this branch was taken.
  ///
  /// Null when LCOV recorded `-`, which means the branch was not executed.
  final int? taken;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CoverageBranch &&
        other.line == line &&
        other.block == block &&
        other.branch == branch &&
        other.taken == taken;
  }

  @override
  int get hashCode => Object.hash(line, block, branch, taken);
}

/// {@template coverde.coverage_branches}
/// Branch coverage for one file.
///
/// A null group means the trace never mentioned branches. An instance with
/// [found] `0` means the trace reported that no branches exist.
/// {@endtemplate}
@immutable
final class CoverageBranches {
  /// {@macro coverde.coverage_branches}
  CoverageBranches({
    required this.hit,
    required this.found,
    required Iterable<CoverageBranch> branches,
  }) : branches = List<CoverageBranch>.unmodifiable(branches);

  /// How many branches were taken at least once.
  final int hit;

  /// How many branches were found.
  final int found;

  /// The branches in this group, sorted by line, block, and branch.
  final List<CoverageBranch> branches;

  static const _branchesEquality = ListEquality<CoverageBranch>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CoverageBranches &&
        other.hit == hit &&
        other.found == found &&
        _branchesEquality.equals(other.branches, branches);
  }

  @override
  int get hashCode => Object.hash(hit, found, _branchesEquality.hash(branches));
}
