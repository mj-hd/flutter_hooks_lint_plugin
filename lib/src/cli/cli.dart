import 'package:args/command_runner.dart';
import 'package:flutter_hooks_lint_plugin/src/cli/analyze.dart';

void run(List<String> args) {
  CommandRunner('flutter_hooks_lint', 'A useful lint tool for flutter_hooks')
    ..addCommand(AnalyzeCommand())
    ..run(args);
}
