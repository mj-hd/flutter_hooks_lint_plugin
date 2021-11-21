import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/option.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('config', () {
    test('load constantHooks', () {
      final source = '''
        flutter_hooks_lint_plugin:
          exhaustive_keys:
            constant_hooks:
              - A
              - B
              - C
      ''';

      final yaml = loadYaml(source);

      expect(
        FlutterHooksRulesPluginOptions.fromYaml(yaml),
        FlutterHooksRulesPluginOptions(
          exhaustiveKeys: ExhaustiveKeysOptions(
            constantHooks: [
              'A',
              'B',
              'C',
            ],
          ),
        ),
      );
    });

    test('load errors', () {
      final source = '''
        flutter_hooks_lint_plugin:
          errors:
            key1: error
            key2: info
            key3: warning
      ''';

      final yaml = loadYaml(source);

      expect(
        FlutterHooksRulesPluginOptions.fromYaml(yaml),
        FlutterHooksRulesPluginOptions(
          errors: ErrorsOptions(
            severity: {
              'key1': AnalysisErrorSeverity.ERROR,
              'key2': AnalysisErrorSeverity.INFO,
              'key3': AnalysisErrorSeverity.WARNING,
            },
          ),
        ),
      );
    });
  });
}
