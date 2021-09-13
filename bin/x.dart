import 'dart:io';

import 'package:cov_utils/cov_utils.dart' show x;

Future<void> main(List<String> arguments) async => x(arguments).catchError(
      (Object e) {
        stdout.write(e);
        exit(1);
      },
    );
