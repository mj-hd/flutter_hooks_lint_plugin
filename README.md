# flutter_hooks_lint_plugin

flutter_hooks_lint_plugin is a dart analyzer plugin for [the flutter hooks](https://pub.dev/packages/flutter_hooks), inspired by [eslint-plugin-react-hooks](https://www.npmjs.com/package/eslint-plugin-react-hooks).

## Rules

### Missing/Unnecessary keys

Lint to detect missing, unnecessary keys in the `useEffect` calling.  
It finds _build variables_ (class fields, local variables, any other build-related variables) in the HookWidget, then compares references of the build variables and specified keys in the `useEffect` calling, and reports a lint error if there are any differences.

```dart
final variable1 = callSomething();
final variable2 = callSomething();

useEffect(() {
  print(variable1);
}, [variable2]); // <= missing key 'variable1', unnecessary key 'variable2'
```

### Avoid nested using of hooks

Lint to detect nested using of hooks which is one of the bad practices.  
It reports a lint error if there are any using of hooks under control flow syntax (`if`, `for`, `while`, ... ).

```dart
if (flag) {
  final variable = useState('hello'); // <= avoid nested hooks
}
```

## Installation

Add `flutter_hooks_lint_plugin` dependency to your `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_hooks_lint_plugin: ^0.5.1
```

Add `flutter_hooks_lint_plugin` plugin directive to your `analyzer_options.yaml`:

```yaml
analyzer:
  plugins:
    - flutter_hooks_lint_plugin
```

Then, run `flutter pub get` and restart your IDE/Editor.

## Options

You can customize plugin's behavior by the `analysis_options.yaml`:

```yaml
flutter_hooks_lint_plugin:
  exhaustive_keys:
    # hooks do not change over the state's lifecycle 
    constant_hooks:
      # default values
      - useRef
      - useIsMounted
      - useFocusNode
      - useContext

      # your custom hooks here
      - useConstantValue
```

## Suppress lints

There are several ways to suppress lints:

1. add `// ignore_for_file: exhaustive_keys, nested_hooks` to suppress lints in the entire file
1. add `// ignore: exhaustive_keys, nested_hooks` to suppress lints at the next or current line
1. add `// ignore_keys: foo, bar` to suppress lints for the specific keys at the next or current line

## CLI

You can also use this plugin by CLI command:

```sh
$ dart pub run flutter_hooks_lint_plugin:flutter_hooks_lint analyze ./

$ flutter pub run flutter_hooks_lint_plugin:flutter_hooks_lint analyze ./
```

## TODO

- [x] support `Fix` (suggestion)

## Contribution

Welcome PRs!

You can develop locally by modifying plugin's dependency to absolute path in `tools/analyzer_plugin/pubspec.yaml`:

```dart
dependencies:
  flutter_hooks_lint_plugin:
    path: /home/mjhd/flutter_hooks_lint_plugin # <= absolute path to the cloned directory
```

## LICENSE

[The MIT License © mjhd](https://github.com/mj-hd/flutter_hooks_lint_plugin/blob/main/LICENSE)
