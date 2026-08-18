import 'package:yaml/yaml.dart';

class Options {
  const Options({
    this.flutterHooksLintPlugin = const FlutterHooksRulesPluginOptions(),
  });

  factory Options.fromYaml(dynamic yaml) => Options(
    flutterHooksLintPlugin: FlutterHooksRulesPluginOptions.fromYaml(yaml),
  );

  final FlutterHooksRulesPluginOptions flutterHooksLintPlugin;

  Options applyYaml(Options other) {
    return Options(
      flutterHooksLintPlugin: flutterHooksLintPlugin.applyYaml(
        other.flutterHooksLintPlugin,
      ),
    );
  }
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

  FlutterHooksRulesPluginOptions applyYaml(
    FlutterHooksRulesPluginOptions other,
  ) {
    return FlutterHooksRulesPluginOptions(
      exhaustiveKeys: exhaustiveKeys.applyYaml(other.exhaustiveKeys),
    );
  }
}

class ExhaustiveKeysOptions {
  static final String _rootKey = 'exhaustive_keys';

  static const defaultConstantHooks = [
    'useRef',
    'useIsMounted',
    'useFocusNode',
    'useContext',
  ];

  const ExhaustiveKeysOptions({this.constantHooks});

  final List<String>? constantHooks;

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

  List<String> get effectiveConstantHooks =>
      constantHooks ?? defaultConstantHooks;

  @override
  String toString() {
    return '{ constantHooks: $constantHooks }';
  }

  @override
  bool operator ==(Object other) =>
      other is ExhaustiveKeysOptions &&
      constantHooks?.length == other.constantHooks?.length &&
      (constantHooks == null ||
          constantHooks!.asMap().entries.fold(
            false,
            (prev, e) => prev | (e.value == other.constantHooks![e.key]),
          ));

  @override
  int get hashCode =>
      constantHooks?.fold(0, (prev, e) => prev! ^ e.hashCode) ?? 0;

  ExhaustiveKeysOptions applyYaml(ExhaustiveKeysOptions other) {
    return ExhaustiveKeysOptions(
      constantHooks: other.constantHooks ?? constantHooks,
    );
  }
}
