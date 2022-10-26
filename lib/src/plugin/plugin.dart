import 'dart:async';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;
import 'package:flutter_hooks_lint_plugin/src/lint/config.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/exhaustive_keys.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/rules_of_hooks.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/utils/cache.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/utils/suppression.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/utils/lint_error.dart';
import 'package:glob/glob.dart';
import 'package:yaml/yaml.dart';

class FlutterHooksRulesPlugin extends ServerPlugin {
  FlutterHooksRulesPlugin({
    required super.resourceProvider,
  });

  AnalysisContextCollection? _contextCollection;
  final _optionsMap = <String, Options>{};

  @override
  List<String> get fileGlobsToAnalyze => const ['**/*.dart'];

  @override
  String get name => 'flutter_hooks_lint_plugin';

  // NOTE: set the protocol version we use
  //  @see https://github.com/dart-lang/sdk/blob/60773b91352872e5b04d254e3aa084a28f403a89/pkg/analysis_server/lib/protocol/protocol_constants.dart#L11
  @override
  String get version => '1.33.1';

  @override
  Future<void> afterNewContextCollection({
    required AnalysisContextCollection contextCollection,
  }) {
    _contextCollection = contextCollection;

    contextCollection.contexts.forEach(_createConfig);

    return super
        .afterNewContextCollection(contextCollection: contextCollection);
  }

  void _createConfig(AnalysisContext analysisContext) {
    final rootPath = analysisContext.contextRoot.root.path;
    final file = analysisContext.contextRoot.optionsFile;

    if (file != null && file.exists) {
      final options = _loadOptions(file);

      _optionsMap[rootPath] = options;
    }
  }

  Options _loadOptions(File? file) {
    if (file == null) return Options();

    final yaml = loadYaml(file.readAsStringSync());

    return Options.fromYaml(yaml);
  }

  @override
  Future<void> analyzeFile({
    required AnalysisContext analysisContext,
    required String path,
  }) async {
    try {
      final resolvedUnit =
          await analysisContext.currentSession.getResolvedUnit(path);

      if (resolvedUnit is ResolvedUnitResult) {
        _processResult(
          analysisContext.contextRoot.root.path,
          resolvedUnit,
        );
      } else {
        channel.sendNotification(plugin.PluginErrorParams(
          false,
          'Failed to analyze ($resolvedUnit)',
          '',
        ).toNotification());
      }
    } on Exception catch (e, s) {
      channel.sendNotification(
        plugin.PluginErrorParams(
          false,
          'Unexpected error: ${e.toString()}',
          s.toString(),
        ).toNotification(),
      );
    }
  }

  void _processResult(
    String rootPath,
    ResolvedUnitResult analysisResult,
  ) {
    final options = _optionsMap[rootPath];
    final path = analysisResult.path;

    _excludeGlobs ??= options?.analyzer.exclude.map((e) => Glob(e)).toList();

    final excluded = _excludeCache.doCache(
      path,
      () => _excludeGlobs!.any((e) => e.matches(path)),
    );

    if (excluded) return;

    final errors = _check(
      rootPath,
      path,
      analysisResult,
    );

    channel.sendNotification(
      plugin.AnalysisErrorsParams(
        path,
        errors.map((e) => e.error).toList(),
      ).toNotification(),
    );
  }

  List<Glob>? _excludeGlobs;
  final Cache<String, bool> _excludeCache = Cache(5000);

  @override
  Future<plugin.EditGetFixesResult> handleEditGetFixes(
    plugin.EditGetFixesParams parameters,
  ) async {
    try {
      final analysisContext = _contextCollection?.contextFor(parameters.file);
      final analysisResult = await analysisContext?.currentSession
          .getResolvedUnit(parameters.file);

      if (analysisContext == null || analysisResult is! ResolvedUnitResult) {
        return plugin.EditGetFixesResult([]);
      }

      final errors = _check(
        analysisContext.contextRoot.root.path,
        parameters.file,
        analysisResult,
      )
          .where(
            (fix) =>
                fix.error.location.file == parameters.file &&
                fix.error.location.offset <= parameters.offset &&
                parameters.offset <=
                    fix.error.location.offset + fix.error.location.length &&
                fix.fixes.isNotEmpty,
          )
          .toList();

      return plugin.EditGetFixesResult(errors);
    } on Exception catch (e, stackTrace) {
      channel.sendNotification(
        plugin.PluginErrorParams(false, e.toString(), stackTrace.toString())
            .toNotification(),
      );

      return plugin.EditGetFixesResult([]);
    }
  }

  List<plugin.AnalysisErrorFixes> _check(
    String rootPath,
    String filePath,
    ResolvedUnitResult analysisResult,
  ) {
    final options = _optionsMap[rootPath];
    final errors = <plugin.AnalysisErrorFixes>[];

    final supression = Suppression(
      content: analysisResult.content,
      lineInfo: analysisResult.unit.lineInfo,
    );

    void onReport(LintError err) {
      if (supression.isSuppressedLintError(err)) {
        return;
      }

      errors.add(
        err.toAnalysisErrorFixes(filePath, analysisResult),
      );
    }

    findExhaustiveKeys(
      analysisResult.unit,
      options: options?.flutterHooksLintPlugin.exhaustiveKeys ??
          ExhaustiveKeysOptions(),
      onReport: onReport,
    );

    findRulesOfHooks(
      analysisResult.unit,
      onReport: onReport,
    );

    return errors;
  }
}
