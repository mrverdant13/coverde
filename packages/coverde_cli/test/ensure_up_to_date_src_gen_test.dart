@Tags(['ci-only'])
library;

import 'package:build_verify/build_verify.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Ensure up-to-date source generation',
    () async {
      await expectBuildClean(
        packageRelativeDirectory: 'packages/coverde_cli',
      );
    },
  );
}
