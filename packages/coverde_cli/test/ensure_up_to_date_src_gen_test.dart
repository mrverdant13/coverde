@Tags(['ci-only'])
library coverde_cli.test.ensure_up_to_date_src_gen_test;

import 'package:build_verify/build_verify.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Ensure up-to-date source generation',
    () {
      expectBuildClean(
        packageRelativeDirectory: 'packages/coverde_cli',
      );
    },
  );
}
