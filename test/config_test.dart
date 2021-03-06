import 'package:flutter_hooks_lint_plugin/src/lint/config.dart';
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

    test('analyzer exclude', () {
      final source = '''
        analyzer:
          exclude:
            - first
            - second*
            - third/*.dart
      ''';

      final yaml = loadYaml(source);

      expect(
        AnalyzerCommonOptions.fromYaml(yaml),
        AnalyzerCommonOptions(
          exclude: [
            'first',
            'second*',
            'third/*.dart',
          ],
        ),
      );
    });
  });
}
