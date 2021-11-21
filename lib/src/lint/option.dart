import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:yaml/yaml.dart';

T? _isTypeOrNull<T extends Object>(dynamic value) {
  return value is T ? value : null;
}

class FlutterHooksRulesPluginOptions {
  static final String _rootKey = 'flutter_hooks_lint_plugin';

  FlutterHooksRulesPluginOptions({
    this.exhaustiveKeys = const ExhaustiveKeysOptions(),
    this.errors = const ErrorsOptions(),
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
      errors: ErrorsOptions.fromYaml(map),
    );
  }

  final ExhaustiveKeysOptions exhaustiveKeys;
  final ErrorsOptions errors;

  @override
  String toString() {
    return '{ exhaustiveKeys: $exhaustiveKeys, errors: $errors }';
  }

  @override
  bool operator ==(Object other) =>
      other is FlutterHooksRulesPluginOptions &&
      exhaustiveKeys == other.exhaustiveKeys &&
      errors == other.errors;

  @override
  int get hashCode => exhaustiveKeys.hashCode ^ errors.hashCode;
}

class ExhaustiveKeysOptions {
  static final String _rootKey = 'exhaustive_keys';

  static const String _constantHooksKey = 'constant_hooks';
  static const List<String> _constantHooksDefault = [
    'useRef',
    'useIsMounted',
    'useFocusNode',
    'useContext',
  ];

  const ExhaustiveKeysOptions({
    this.constantHooks = _constantHooksDefault,
  });

  final List<String> constantHooks;

  factory ExhaustiveKeysOptions.fromYaml(dynamic yaml) {
    final map = yaml[_rootKey];

    if (map is! YamlMap) {
      return ExhaustiveKeysOptions();
    }

    return ExhaustiveKeysOptions(
      constantHooks: _isTypeOrNull<YamlList>(map[_constantHooksKey])
              ?.value
              .whereType<String>()
              .toList() ??
          _constantHooksDefault,
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
  int get hashCode =>
      constantHooks.fold<int>(0, (prev, e) => prev ^ e.hashCode);
}

class ErrorsOptions {
  static final String _rootKey = 'errors';

  const ErrorsOptions({
    this.severity = const {},
  });

  final Map<String, AnalysisErrorSeverity> severity;

  factory ErrorsOptions.fromYaml(dynamic yaml) {
    final map = yaml[_rootKey];

    if (map is! YamlMap) {
      return ErrorsOptions();
    }

    return ErrorsOptions(
      severity: map.map(
        (key, value) => MapEntry(
          key,
          AnalysisErrorSeverity(
            value.toUpperCase(),
          ),
        ),
      ),
    );
  }

  @override
  String toString() {
    return severity.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is ErrorsOptions &&
      severity.length == other.severity.length &&
      severity.entries.every(
        (t) => other.severity.entries
            .any((o) => t.key == o.key && t.value == o.value),
      );

  @override
  int get hashCode => severity.entries.fold(
        0,
        (prev, e) => prev ^ e.key.hashCode ^ e.value.hashCode,
      );
}
