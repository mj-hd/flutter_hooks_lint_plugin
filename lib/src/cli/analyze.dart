import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/src/dart/analysis/driver_based_analysis_context.dart';
import 'package:args/command_runner.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/config.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/exhaustive_keys.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/rules_of_hooks.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/utils/lint_error.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/utils/suppression.dart';
import 'package:glob/glob.dart';
import 'package:logging/logging.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;

final log = Logger('analyze');

class AnalyzeCommand extends Command {
  @override
  final name = 'analyze';

  @override
  final description = 'analyze code';

  AnalyzeCommand() {
    argParser
      ..addFlag('verbose', abbr: 'v')
      ..addFlag('debug', abbr: 'd');
  }

  @override
  Future<void> run() async {
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    });

    if (argResults?['verbose'] == true) {
      Logger.root.level = Level.INFO;
    }

    if (argResults?['debug'] == true) {
      Logger.root.level = Level.ALL;
    }

    log.finer('run');

    if (argResults?.arguments.isEmpty ?? true) {
      throw UsageException('required paths argument', argParser.usage);
    }

    final paths =
        argResults!.rest.map(path.absolute).map(path.normalize).toList();

    final resourceProvider = PhysicalResourceProvider.INSTANCE;

    final contextCollection = AnalysisContextCollectionImpl(
      resourceProvider: resourceProvider,
      includedPaths: paths,
    );

    final errors = <String>[];

    for (final context in contextCollection.contexts) {
      final results = await _checkContext(context);

      for (final result in results) {
        print(result);
      }

      errors.addAll(results);
    }

    if (errors.isNotEmpty) {
      print('${errors.length} lint error(s) found');
      exit(-1);
    }
  }

  Future<List<String>> _checkContext(DriverBasedAnalysisContext context) async {
    log.finer('_checkContext(${context.contextRoot.root.path})');

    final errors = <String>[];

    final options = _loadOptions(context.contextRoot.optionsFile);

    final excludeGlobs = options.analyzer.exclude.map((e) => Glob(e)).toList();

    for (final filePath in context.contextRoot.analyzedFiles()) {
      if (!filePath.endsWith('.dart')) continue;
      if (excludeGlobs.any((e) => e.matches(filePath))) continue;

      log.finest('resolving for $filePath');

      final result = await context.currentSession.getResolvedUnit(filePath);

      if (result is ResolvedUnitResult) {
        log.finest('resolving for $filePath => Success');

        errors.addAll(
          _check(filePath, result, options.flutterHooksLintPlugin).map(
            (err) => err.toReadableString(
              filePath,
              result.unit,
            ),
          ),
        );
      }
    }

    return errors;
  }

  Options _loadOptions(File? file) {
    log.finer('_loadOptions(${file?.path})');
    if (file == null) return Options();

    final yaml = loadYaml(file.readAsStringSync());

    log.finest('_loadOptions(${file.path}) => $yaml');

    return Options.fromYaml(yaml);
  }

  List<LintError> _check(
    String filePath,
    ResolvedUnitResult result,
    FlutterHooksRulesPluginOptions options,
  ) {
    log.finer('_check($filePath)');

    final errors = <LintError>[];

    final supression = Suppression(
      content: result.content,
      lineInfo: result.unit.lineInfo,
    );

    void onReport(LintError err) {
      log.finest('report callback ($err)');

      if (supression.isSuppressedLintError(err)) {
        log.finest('report callback ($err) => Supressed');
        return;
      }

      errors.add(err);
      log.finest('report callback ($err) => reported ${err.code}');
    }

    log.finest('find exhaustive_keys');

    findExhaustiveKeys(
      result.unit,
      options: options.exhaustiveKeys,
      onReport: onReport,
    );

    log.finest('find rules_of_hooks');

    findRulesOfHooks(
      result.unit,
      onReport: onReport,
    );

    return errors;
  }
}
