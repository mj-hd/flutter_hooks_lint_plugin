// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/context/packages.dart';
import 'package:analyzer/src/workspace/pub.dart';
import 'package:analyzer_testing/package_config_file_builder.dart';
import 'package:analyzer_testing/resource_provider_mixin.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/analysis_options_loader.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AnalysisOptionsLoaderTest);
  });
}

@reflectiveTest
class AnalysisOptionsLoaderTest with ResourceProviderMixin {
  final loader = AnalysisOptionsLoader();

  PackageConfigWorkspace _newWorkspace() {
    newPubspecYamlFile('/workspace', 'name: test');

    final packageConfig = PackageConfigFileBuilder()
      ..add(name: 'test', rootFolder: getFolder('/workspace'));

    newPackageConfigJsonFile('/workspace', packageConfig.toContent());

    return PackageConfigWorkspace.find(
      resourceProvider,
      Packages.empty,
      convertPath('/workspace'),
    )!;
  }

  void test_load_doesNotExist() {
    final file = newFile('/workspace/test.dart', '');
    final workspace = _newWorkspace();
    final package = workspace.findPackageFor(file.path);

    final options = loader.load(package, file);

    expect(options.flutterHooksLintPlugin.exhaustiveKeys.constantHooks, null);
  }

  void test_load_empty() {
    newFile('/workspace/analysis_options.yaml', '# Empty');

    final file = newFile('/workspace/test.dart', '');
    final workspace = _newWorkspace();
    final package = workspace.findPackageFor(file.path);

    final options = loader.load(package, file);

    expect(options.flutterHooksLintPlugin.exhaustiveKeys.constantHooks, null);
  }

  void test_load_simple() {
    newFile('/workspace/analysis_options.yaml', '''
flutter_hooks_lint_plugin:
  exhaustive_keys:
    constant_hooks:
      - useStable
''');

    final file = newFile('/workspace/test.dart', '');
    final workspace = _newWorkspace();
    final package = workspace.findPackageFor(file.path);

    final options = loader.load(package, file);

    expect(options.flutterHooksLintPlugin.exhaustiveKeys.constantHooks, [
      'useStable',
    ]);
  }

  void test_load_include() {
    newFile('/workspace/base.yaml', '''
flutter_hooks_lint_plugin:
  exhaustive_keys:
    constant_hooks:
      - useBase
''');

    newFile('/workspace/analysis_options.yaml', '''
include: base.yaml
''');

    final file = newFile('/workspace/test.dart', '');
    final workspace = _newWorkspace();
    final package = workspace.findPackageFor(file.path);

    final options = loader.load(package, file);

    expect(options.flutterHooksLintPlugin.exhaustiveKeys.constantHooks, [
      'useBase',
    ]);
  }

  void test_load_include_local_overrides() {
    newFile('/workspace/base.yaml', '''
flutter_hooks_lint_plugin:
  exhaustive_keys:
    constant_hooks:
      - useBase
''');

    newFile('/workspace/analysis_options.yaml', '''
include: base.yaml

flutter_hooks_lint_plugin:
  exhaustive_keys:
    constant_hooks:
      - useLocal
''');

    final file = newFile('/workspace/test.dart', '');
    final workspace = _newWorkspace();
    final package = workspace.findPackageFor(file.path);

    final options = loader.load(package, file);

    expect(options.flutterHooksLintPlugin.exhaustiveKeys.constantHooks, [
      'useLocal',
    ]);
  }

  void test_load_include_local_does_not_override_unspecified_options() {
    newFile('/workspace/base.yaml', '''
flutter_hooks_lint_plugin:
  exhaustive_keys:
    constant_hooks:
      - useBase
''');

    newFile('/workspace/analysis_options.yaml', '''
include: base.yaml

flutter_hooks_lint_plugin:
''');

    final file = newFile('/workspace/test.dart', '');
    final workspace = _newWorkspace();
    final package = workspace.findPackageFor(file.path);

    final options = loader.load(package, file);

    expect(options.flutterHooksLintPlugin.exhaustiveKeys.constantHooks, [
      'useBase',
    ]);
  }

  void test_load_include_local_empty_list_overrides() {
    newFile('/workspace/base.yaml', '''
flutter_hooks_lint_plugin:
  exhaustive_keys:
    constant_hooks:
      - useBase
''');

    newFile('/workspace/analysis_options.yaml', '''
include: base.yaml

flutter_hooks_lint_plugin:
  exhaustive_keys:
    constant_hooks: []
''');

    final file = newFile('/workspace/test.dart', '');
    final workspace = _newWorkspace();
    final package = workspace.findPackageFor(file.path);

    final options = loader.load(package, file);

    expect(
      options.flutterHooksLintPlugin.exhaustiveKeys.constantHooks,
      isEmpty,
    );
  }

  void test_load_nested_options() {
    newFile('/workspace/analysis_options.yaml', '''
flutter_hooks_lint_plugin:
  exhaustive_keys:
    constant_hooks:
      - useWorkspace
''');

    newFile('/workspace/nested/analysis_options.yaml', '''
flutter_hooks_lint_plugin:
  exhaustive_keys:
    constant_hooks:
      - useNested
''');

    final workspaceFile = newFile('/workspace/lib/test.dart', '');
    final nestedFile = newFile('/workspace/nested/lib/test.dart', '');

    final workspace = _newWorkspace();
    final package = workspace.findPackageFor(workspaceFile.path);

    final workspaceOptions = loader.load(package, workspaceFile);
    final nestedOptions = loader.load(package, nestedFile);

    expect(
      workspaceOptions.flutterHooksLintPlugin.exhaustiveKeys.constantHooks,
      ['useWorkspace'],
    );
    expect(nestedOptions.flutterHooksLintPlugin.exhaustiveKeys.constantHooks, [
      'useNested',
    ]);
  }
}
