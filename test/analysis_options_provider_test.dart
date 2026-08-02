// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/resource_provider_mixin.dart';
import 'package:flutter_hooks_lint_plugin/src/analysis_options_provider.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:yaml/yaml.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AnalysisOptionsProviderTest);
  });
}

@reflectiveTest
class AnalysisOptionsProviderTest with ResourceProviderMixin {
  final provider = const AnalysisOptionsProvider();

  void test_getOptions_crawlUp_hasInFolder() {
    newFile('/analysis_options.yaml', 'root: true');
    newFile('/workspace/analysis_options.yaml', 'workspace: true');

    final options = provider.getOptions(getFolder('/workspace'));

    expect(options, containsPair('workspace', true));
    expect(options, isNot(contains('root')));
  }

  void test_getOptions_crawlUp_hasInParent() {
    newFile('/analysis_options.yaml', 'root: true');
    newFile('/workspace/analysis_options.yaml', 'workspace: true');
    newFolder('/workspace/packages/plugin');

    final options = provider.getOptions(
      getFolder('/workspace/packages/plugin'),
    );

    expect(options, containsPair('workspace', true));
    expect(options, isNot(contains('root')));
  }

  void test_getOptions_doesNotExist() {
    newFolder('/workspace');

    expect(provider.getOptions(getFolder('/workspace')), isEmpty);
  }

  void test_getOptions_empty() {
    newFile('/workspace/analysis_options.yaml', '# Empty');

    expect(provider.getOptions(getFolder('/workspace')), isEmpty);
  }

  void test_getOptions_invalid() {
    newFile('/workspace/analysis_options.yaml', 'analyzer: [');

    expect(provider.getOptions(getFolder('/workspace')), isEmpty);
  }

  void test_getOptions_simple() {
    newFile('/workspace/analysis_options.yaml', '''
flutter_hooks_lint_plugin:
  exhaustive_keys:
    constant_hooks:
      - useStable
''');

    final options = provider.getOptions(getFolder('/workspace'));
    final pluginOptions = options['flutter_hooks_lint_plugin'] as YamlMap;
    final exhaustiveKeys = pluginOptions['exhaustive_keys'] as YamlMap;

    expect(exhaustiveKeys['constant_hooks'], ['useStable']);
  }
}
