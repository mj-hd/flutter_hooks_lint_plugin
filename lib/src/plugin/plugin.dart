import 'dart:async';

import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer/src/dart/analysis/driver_based_analysis_context.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;
import 'package:flutter_hooks_lint_plugin/src/plugin/exhaustive_keys.dart';
import 'package:flutter_hooks_lint_plugin/src/plugin/rules_of_hooks.dart';
import 'package:flutter_hooks_lint_plugin/src/plugin/utils.dart';

class FlutterHooksRulesPlugin extends ServerPlugin {
  FlutterHooksRulesPlugin(ResourceProvider? provider) : super(provider);

  var _filesFromSetPriorityFilesRequest = <String>[];

  @override
  List<String> get fileGlobsToAnalyze => const ['**/*.dart'];

  @override
  String get name => 'flutter_hooks_lint_plugin';

  @override
  String get version => '1.0.0';

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

    runZonedGuarded(
      () {
        dartDriver.results.listen((analysisResult) {
          if (analysisResult is ResolvedUnitResult) {
            _processResult(
              dartDriver,
              analysisResult,
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

  void _processResult(
    AnalysisDriver dartDriver,
    ResolvedUnitResult analysisResult,
  ) {
    final path = analysisResult.path;
    final unit = analysisResult.unit;

    try {
      final errors = _check(dartDriver, path, unit, analysisResult);

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
    CompilationUnit unit,
    ResolvedUnitResult analysisResult,
  ) {
    final errors = <plugin.AnalysisErrorFixes>[];

    void report(LintError err) {
      errors.add(
        plugin.AnalysisErrorFixes(
          err.toAnalysisError(filePath, unit),
        ),
      );
    }

    findExhaustiveKeys(
      unit,
      onMissingKeysReport: (keys, node) {
        report(LintError.missingKeys(keys, node));
      },
      onUnnecessaryKeysReport: (keys, node) {
        report(LintError.unnecessaryKeys(keys, node));
      },
    );

    findRulesOfHooks(
      unit,
      onNestedHooksReport: (hookName, node) {
        report(LintError.nestedHooks(hookName, node));
      },
    );

    return errors;
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
