import 'dart:isolate';

import 'package:flutter_hooks_lint_plugin/plugin.dart';

void main(List<String> args, SendPort sendPort) {
  start(args, sendPort);
}
