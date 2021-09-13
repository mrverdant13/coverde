import 'dart:io';

import 'package:cov_utils/cov_utils.dart' show cov;

Future<void> main(List<String> arguments) async => cov(arguments).catchError(
      (Object e) {
        stdout.write(e);
        exit(1);
      },
    );
