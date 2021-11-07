# flutter_hooks_lint_plugin

**NOTE: This repository is under development, may contain buggy behavior, or missing features, ...**

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
