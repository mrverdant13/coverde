import 'package:coverde/src/entities/entities.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  group('$PackageVersioningInfo', () {
    test('supports value comparison', () {
      final subject = PackageVersioningInfo(
        packageName: 'coverde',
        packageVersion: Version.parse('0.2.0+1'),
        dartVersionConstraint: VersionConstraint.parse('>=3.0.0 <4.0.0'),
      );
      final same = PackageVersioningInfo(
        packageName: 'coverde',
        packageVersion: Version.parse('0.2.0+1'),
        dartVersionConstraint: VersionConstraint.parse('>=3.0.0 <4.0.0'),
      );
      final other = PackageVersioningInfo(
        packageName: 'coverde',
        packageVersion: Version.parse('0.2.0+2'),
        dartVersionConstraint: VersionConstraint.parse('>=3.0.0 <4.0.0'),
      );
      expect(subject, same);
      expect(subject, isNot(other));
    });

    test('supports hash code comparison', () {
      final subject = PackageVersioningInfo(
        packageName: 'coverde',
        packageVersion: Version.parse('0.2.0+1'),
        dartVersionConstraint: VersionConstraint.parse('>=3.0.0 <4.0.0'),
      );
      final same = PackageVersioningInfo(
        packageName: 'coverde',
        packageVersion: Version.parse('0.2.0+1'),
        dartVersionConstraint: VersionConstraint.parse('>=3.0.0 <4.0.0'),
      );
      final other = PackageVersioningInfo(
        packageName: 'coverde',
        packageVersion: Version.parse('0.2.0+2'),
        dartVersionConstraint: VersionConstraint.parse('>=3.0.0 <4.0.0'),
      );
      expect(subject.hashCode, same.hashCode);
      expect(subject.hashCode, isNot(other.hashCode));
    });

    test('supports string representation', () {
      final subject = PackageVersioningInfo(
        packageName: 'coverde',
        packageVersion: Version.parse('0.2.0+1'),
        dartVersionConstraint: VersionConstraint.parse('>=3.0.0 <4.0.0'),
      );
      expect(
        subject.toString(),
        'PackageVersioningInfo('
        'packageName: coverde, '
        'packageVersion: 0.2.0+1, '
        'dartVersionConstraint: >=3.0.0 <4.0.0)',
      );
    });
  });
}
