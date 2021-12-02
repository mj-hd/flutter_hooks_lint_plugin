import 'dart:async';

import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer/src/dart/analysis/driver_based_analysis_context.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;
import 'package:flutter_hooks_lint_plugin/src/lint/config.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/exhaustive_keys.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/rules_of_hooks.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/utils/cache.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/utils/supression.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/utils/lint_error.dart';
import 'package:glob/glob.dart';
import 'package:yaml/yaml.dart';

class FlutterHooksRulesPlugin extends ServerPlugin {
  FlutterHooksRulesPlugin(ResourceProvider? provider) : super(provider);

  var _filesFromSetPriorityFilesRequest = <String>[];

  @override
  List<String> get fileGlobsToAnalyze => const ['**/*.dart'];

  @override
  String get name => 'flutter_hooks_lint_plugin';

  // NOTE: set the same version as the server
  //  @see https://github.com/dart-lang/sdk/blob/e916841bcc5687e5fea4221d9fdbee2ccc3e412e/pkg/analyzer_plugin/lib/plugin/plugin.dart#L405
  @override
  String get version => '1.0.0-alpha.0';

  @override
  AnalysisDriverGeneric createAnalysisDriver(plugin.ContextRoot contextRoot) {
    final rootPath = contextRoot.root;
    final locator =
        ContextLocator(resourceProvider: resourceProvider).locateRoots(
      includedPaths: [rootPath],
      excludedPaths: [
        ...contextRoot.exclude,
      ],
      optionsFile: contextRoot.optionsFile,
    );

    if (locator.isEmpty) {
      final error = StateError('Unexpected empty context');
      channel.sendNotification(plugin.PluginErrorParams(
        true,
        error.message,
        error.stackTrace.toString(),
      ).toNotification());

      throw error;
    }

    final builder = ContextBuilder(
      resourceProvider: resourceProvider,
    );

    final analysisContext = builder.createContext(contextRoot: locator.first);
    final context = analysisContext as DriverBasedAnalysisContext;
    final dartDriver = context.driver;
    var options = Options();

    try {
      options = _loadOptions(context.contextRoot.optionsFile);
    } catch (e, s) {
      channel.sendNotification(
        plugin.PluginErrorParams(
          true,
          'Failed to load options: ${e.toString()}',
          s.toString(),
        ).toNotification(),
      );
    }

    runZonedGuarded(
      () {
        dartDriver.results.listen((analysisResult) {
          if (analysisResult is ResolvedUnitResult) {
            _processResult(
              dartDriver,
              analysisResult,
              options,
            );
          } else if (analysisResult is ErrorsResult) {
            channel.sendNotification(plugin.PluginErrorParams(
              false,
              'ErrorResult ${analysisResult}',
              '',
            ).toNotification());
          }
        });
      },
      (Object e, StackTrace stackTrace) {
        channel.sendNotification(
          plugin.PluginErrorParams(
            false,
            'Unexpected error: ${e.toString()}',
            stackTrace.toString(),
          ).toNotification(),
        );
      },
    );

    return dartDriver;
  }

  List<Glob>? _excludeGlobs;
  final Cache<String, bool> _excludeCache = Cache(5000);

  void _processResult(
    AnalysisDriver dartDriver,
    ResolvedUnitResult analysisResult,
    Options options,
  ) {
    final path = analysisResult.path;

    _excludeGlobs ??= options.analyzer.exclude.map((e) => Glob(e)).toList();

    final excluded = _excludeCache.doCache(
      path,
      () => _excludeGlobs!.any((e) => e.matches(path)),
    );

    if (excluded) return;

    try {
      final errors = _check(
          dartDriver, path, analysisResult, options.flutterHooksLintPlugin);

      channel.sendNotification(
        plugin.AnalysisErrorsParams(
          path,
          errors.map((e) => e.error).toList(),
        ).toNotification(),
      );
    } catch (e, stackTrace) {
      channel.sendNotification(
        plugin.PluginErrorParams(
          false,
          e.toString(),
          stackTrace.toString(),
        ).toNotification(),
      );
    }
  }

  List<plugin.AnalysisErrorFixes> _check(
    AnalysisDriver driver,
    String filePath,
    ResolvedUnitResult analysisResult,
    FlutterHooksRulesPluginOptions options,
  ) {
    final errors = <plugin.AnalysisErrorFixes>[];

    final supression = Supression(
      content: analysisResult.content,
      lineInfo: analysisResult.unit.lineInfo!,
    );

    void report(LintError err, [LintFix? fix]) {
      if (supression.isSupressedLintError(err)) {
        return;
      }

      errors.add(
        plugin.AnalysisErrorFixes(
          err.toAnalysisError(filePath, analysisResult.unit),
          fixes: fix != null
              ? [fix.toAnalysisFix(filePath, analysisResult)]
              : null,
        ),
      );
    }

    findExhaustiveKeys(
      analysisResult.unit,
      options: options.exhaustiveKeys,
      onMissingKeyReport: (key, kind, ctxNode, errNode) {
        report(LintError.missingKey(key, kind, ctxNode, errNode));
      },
      onUnnecessaryKeyReport: (key, kind, ctxNode, errNode) {
        report(LintError.unnecessaryKey(key, kind, ctxNode, errNode));
      },
      onFunctionKeyReport: (key, _, ctxNode, errNode) {
        report(LintError.functionKey(key, ctxNode, errNode));
      },
    );

    findRulesOfHooks(
      analysisResult.unit,
      onNestedHooksReport: (hookName, node) {
        report(LintError.nestedHooks(hookName, node));
      },
    );

    return errors;
  }

  Options _loadOptions(File? file) {
    if (file == null) return Options();

    final yaml = loadYaml(file.readAsStringSync());

    return Options.fromYaml(yaml);
  }

  // from https://github.com/dart-code-checker/dart-code-metrics/blob/e8e14d44b940a5b29d33a782432f853ee42ac7a0/lib/src/analyzer_plugin/analyzer_plugin.dart#L274
  @override
  void contentChanged(String path) {
    super.driverForPath(path)?.addFile(path);
  }

  @override
  Future<plugin.AnalysisSetContextRootsResult> handleAnalysisSetContextRoots(
    plugin.AnalysisSetContextRootsParams parameters,
  ) async {
    final result = await super.handleAnalysisSetContextRoots(parameters);
    _updatePriorityFiles();

    return result;
  }

  @override
  Future<plugin.AnalysisSetPriorityFilesResult> handleAnalysisSetPriorityFiles(
    plugin.AnalysisSetPriorityFilesParams parameters,
  ) async {
    _filesFromSetPriorityFilesRequest = parameters.files;
    _updatePriorityFiles();

    return plugin.AnalysisSetPriorityFilesResult();
  }

  void _updatePriorityFiles() {
    final filesToFullyResolve = {
      ..._filesFromSetPriorityFilesRequest,
      for (final driver2 in driverMap.values)
        ...(driver2 as AnalysisDriver).addedFiles,
    };

    final filesByDriver = <AnalysisDriverGeneric, List<String>>{};
    for (final file in filesToFullyResolve) {
      final contextRoot = contextRootContaining(file);
      if (contextRoot != null) {
        final driver = driverMap[contextRoot];
        if (driver != null) {
          filesByDriver.putIfAbsent(driver, () => <String>[]).add(file);
        }
      }
    }
    filesByDriver.forEach((driver, files) {
      driver.priorityFiles = files;
    });
  }
}
