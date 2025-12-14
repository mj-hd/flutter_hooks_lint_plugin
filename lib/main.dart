import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/src/analysis_options/analysis_options_provider.dart';
import 'package:analyzer/workspace/workspace.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/config.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/exhaustive_keys.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/rules_of_hooks.dart';
import 'package:logging/logging.dart';

final plugin = FlutterHooksLintPlugin();

class FlutterHooksLintPlugin extends Plugin {
  final _context = FlutterHooksLintPluginContext();

  @override
  void start() {
    //final logFile = File('/Users/mjhd/flutter_hooks_lint_plugin.log');
    //logFile.createSync();
    //final logSink = logFile.openWrite(mode: FileMode.writeOnlyAppend);

    //hierarchicalLoggingEnabled = true;
    //Logger.root.level = Level.ALL;
    //Logger.root.onRecord.listen((data) {
    //  final record =
    //      '[${data.level}] (${data.loggerName}) ${data.time}: ${data.message} (${data.object})';
    //  logSink.writeln(record);
    //});

    Logger.root.fine('start');
  }

  @override
  void register(PluginRegistry registry) {
    Logger.root.fine('register');
    registry.registerLintRule(ExhaustiveKeysRule(_context));
    registry.registerLintRule(RulesOfHooksRule(_context));
    registry.registerFixForRule(
      ExhaustiveKeysRule.codeForMissingKey,
      ({required CorrectionProducerContext context}) =>
          MissingKeyFix(context: context, pluginContext: _context),
    );
    registry.registerFixForRule(
      ExhaustiveKeysRule.codeForUnnecessaryKey,
      ({required CorrectionProducerContext context}) =>
          UnnecessaryKeyFix(context: context, pluginContext: _context),
    );
  }

  @override
  final name = 'flutter_hooks_lint_plugin';
}

class FlutterHooksLintPluginContext {
  FlutterHooksLintPluginContext();

  final _optionsForContextMap = {};

  Options optionsForPackage(WorkspacePackage? package) {
    if (package == null) return const Options();

    final key = package.root.path;
    if (_optionsForContextMap[key] == null) {
      final provider = AnalysisOptionsProvider();
      final optionsYaml = provider.getOptions(package.root);
      _optionsForContextMap[key] = Options.fromYaml(optionsYaml);
    }

    return _optionsForContextMap[key];
  }
}
