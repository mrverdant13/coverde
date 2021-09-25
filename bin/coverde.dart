import 'dart:io';

import 'package:coverde/coverde.dart' show coverde;

Future<void> main(List<String> arguments) async =>
    coverde(arguments).catchError(
      (Object e) {
        stdout.write(e);
        exit(1);
      },
    );
