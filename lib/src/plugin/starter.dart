import 'dart:isolate';

import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin/starter.dart';
import 'package:flutter_hooks_lint_plugin/src/plugin/plugin.dart';

void start(Iterable<String> _, SendPort sendPort) {
  ServerPluginStarter(
    FlutterHooksRulesPlugin(
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    ),
  ).start(sendPort);
}
