import 'package:yaml/yaml.dart';

class Options {
  const Options({
    this.analyzer = const AnalyzerCommonOptions(),
    this.flutterHooksLintPlugin = const FlutterHooksRulesPluginOptions(),
  });

  factory Options.fromYaml(dynamic yaml) => Options(
        analyzer: AnalyzerCommonOptions.fromYaml(yaml),
        flutterHooksLintPlugin: FlutterHooksRulesPluginOptions.fromYaml(yaml),
      );

  final AnalyzerCommonOptions analyzer;
  final FlutterHooksRulesPluginOptions flutterHooksLintPlugin;
}

class AnalyzerCommonOptions {
  static final String _rootKey = 'analyzer';

  const AnalyzerCommonOptions({
    this.exclude = const [],
  });

  final List<String> exclude;

  factory AnalyzerCommonOptions.fromYaml(dynamic yaml) {
    if (yaml is! YamlMap) {
      return AnalyzerCommonOptions();
    }

    final map = yaml[_rootKey];

    if (map is! YamlMap) {
      return AnalyzerCommonOptions();
    }

    final exclude = map['exclude'];

    if (exclude is! YamlList) {
      return AnalyzerCommonOptions();
    }

    return AnalyzerCommonOptions(
      exclude: exclude.value.whereType<String>().toList(),
    );
  }

  @override
  String toString() {
    return '{ exclude: $exclude }';
  }

  @override
  bool operator ==(Object other) =>
      other is AnalyzerCommonOptions &&
      exclude.length == other.exclude.length &&
      exclude.every((e) => other.exclude.contains(e));

  @override
  int get hashCode => exclude.fold(0, (acc, e) => acc ^ e.hashCode);
}

class FlutterHooksRulesPluginOptions {
  static final String _rootKey = 'flutter_hooks_lint_plugin';

  const FlutterHooksRulesPluginOptions({
    this.exhaustiveKeys = const ExhaustiveKeysOptions(),
  });

  factory FlutterHooksRulesPluginOptions.fromYaml(dynamic yaml) {
    if (yaml is! YamlMap) {
      return FlutterHooksRulesPluginOptions();
    }

    final map = yaml[_rootKey];

    if (map is! YamlMap) {
      return FlutterHooksRulesPluginOptions();
    }

    return FlutterHooksRulesPluginOptions(
      exhaustiveKeys: ExhaustiveKeysOptions.fromYaml(map),
    );
  }

  final ExhaustiveKeysOptions exhaustiveKeys;

  @override
  String toString() {
    return '{ exhaustiveKeys: $exhaustiveKeys }';
  }

  @override
  bool operator ==(Object other) =>
      other is FlutterHooksRulesPluginOptions &&
      exhaustiveKeys == other.exhaustiveKeys;

  @override
  int get hashCode => exhaustiveKeys.hashCode;
}

class ExhaustiveKeysOptions {
  static final String _rootKey = 'exhaustive_keys';

  const ExhaustiveKeysOptions({
    this.constantHooks = const [
      'useRef',
      'useIsMounted',
      'useFocusNode',
      'useContext',
    ],
  });

  final List<String> constantHooks;

  factory ExhaustiveKeysOptions.fromYaml(dynamic yaml) {
    final map = yaml[_rootKey];

    if (map is! YamlMap) {
      return ExhaustiveKeysOptions();
    }

    final constantHooks = map['constant_hooks'];

    if (constantHooks is! YamlList) {
      return ExhaustiveKeysOptions();
    }

    return ExhaustiveKeysOptions(
      constantHooks: constantHooks.value.whereType<String>().toList(),
    );
  }

  @override
  String toString() {
    return '{ constantHooks: $constantHooks }';
  }

  @override
  bool operator ==(Object other) =>
      other is ExhaustiveKeysOptions &&
      constantHooks.length == other.constantHooks.length &&
      constantHooks.asMap().entries.fold(
          false, (prev, e) => prev | (e.value == other.constantHooks[e.key]));

  @override
  int get hashCode => constantHooks.fold(0, (prev, e) => prev ^ e.hashCode);
}
