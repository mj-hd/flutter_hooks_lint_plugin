import 'package:flutter_hooks_lint_plugin/src/plugin/config.dart';
import 'package:flutter_hooks_lint_plugin/src/plugin/exhaustive_keys.dart';
import 'package:test/test.dart';

import 'utils.dart';

class _FoundKey {
  _FoundKey(this.name, this.kind);

  final String name;
  final String? kind;

  @override
  String toString() {
    return 'Key $name $kind';
  }

  @override
  bool operator ==(Object other) =>
      other is _FoundKey && name == other.name && kind == other.kind;

  @override
  int get hashCode => name.hashCode ^ kind.hashCode;
}

class _TestResult {
  final missingKeys = <_FoundKey>[];
  final unnecessaryKeys = <_FoundKey>[];
  final functionKeys = <_FoundKey>[];
}

Future<_TestResult> _find(
  String source, [
  ExhaustiveKeysOptions? options,
]) async {
  final unit = await compileCode(source);

  final result = _TestResult();

  findExhaustiveKeys(
    unit,
    options: options ?? ExhaustiveKeysOptions(),
    onMissingKeyReport: (key, kind, node) {
      result.missingKeys.add(_FoundKey(key, kind));
    },
    onUnnecessaryKeyReport: (key, kind, node) {
      result.unnecessaryKeys.add(_FoundKey(key, kind));
    },
    onFunctionKeyReport: (key, kind, node) {
      result.functionKeys.add(_FoundKey(key, kind));
    },
  );

  return result;
}

Future<List<_FoundKey>> _findMissingKeys(
  String source, [
  ExhaustiveKeysOptions? options,
]) async {
  return (await _find(source, options)).missingKeys;
}

Future<List<_FoundKey>> _findUnnecessaryKeys(
  String source, [
  ExhaustiveKeysOptions? options,
]) async {
  return (await _find(source, options)).unnecessaryKeys;
}

Future<List<_FoundKey>> _findFunctionKeys(
  String source, [
  ExhaustiveKeysOptions? options,
]) async {
  return (await _find(source, options)).functionKeys;
}

void main() {
  setUpLogging();

  group('missing keys', () {
    test('report class property reference', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.dep,
          }): super(key: key);

          final String dep;

          @override
          Widget build(BuildContext context) {
            useEffect(() {
              print(dep);
            }, []);

            return Text('TestWidget');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, [_FoundKey('dep', 'class field')]);
    });

    test('report local variable reference', () async {
      final source = '''
        import 'dart:math';

        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
          }): super(key: key);

          @override
          Widget build(BuildContext context) {
            final dep = Random();

            useEffect(() {
              print(dep);
            }, []);

            return Text('TestWidget');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, [_FoundKey('dep', 'local variable')]);
    });

    test('report local function reference', () async {
      final source = '''
        import 'dart:math';

        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
          }): super(key: key);

          @override
          Widget build(BuildContext context) {
            void dep() {
              print('hello');
            }

            useEffect(() {
              dep();
            }, []);

            return Text('TestWidget');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, [_FoundKey('dep', 'local function')]);
    });

    test('ignore useEffect without keys', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.dep,
          }): super(key: key);

          final String dep;

          @override
          Widget build(BuildContext context) {
            useEffect(() {
              print(dep);
            });

            return Text('TestWidget');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, []);
    });

    test('report hooks with keys', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.dep,
          }): super(key: key);

          final String dep;

          @override
          Widget build(BuildContext context) {
            final val1 = useAnimationController(keys: [dep]);
            final val2 = usePageController(keys: [dep]);
            final val3 = useScrollController(keys: [dep]);
            final val4 = useSingleTickerProvider(keys: [dep]);
            final val5 = useStreamController(keys: [dep]);
            final val6 = useTabController(keys: [dep]);
            final val7 = useTransformationController(keys: [dep]);
            final val8 = useMemoized(() => dep, [dep]);
            final val9 = useValueNotifier(0, [dep]);

            useEffect(() {
              print('\$val1\$val2\$val3\$val4\$val5\$val6\$val7\$val8\$val9');
            }, []);

            return Text('TestWidget');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, [
        _FoundKey('val1', 'local variable'),
        _FoundKey('val2', 'local variable'),
        _FoundKey('val3', 'local variable'),
        _FoundKey('val4', 'local variable'),
        _FoundKey('val5', 'local variable'),
        _FoundKey('val6', 'local variable'),
        _FoundKey('val7', 'local variable'),
        _FoundKey('val8', 'local variable'),
        _FoundKey('val9', 'local variable'),
      ]);
    });

    test('ignore hooks with empty keys', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
          }): super(key: key);

          @override
          Widget build(BuildContext context) {
            final val1 = useAnimationController(keys: []);
            final val2 = usePageController(keys: []);
            final val3 = useScrollController(keys: []);
            final val4 = useSingleTickerProvider(keys: []);
            final val5 = useStreamController(keys: []);
            final val6 = useTabController(keys: []);
            final val7 = useTransformationController(keys: []);
            final val8 = useMemoized(() => 0, []);
            final val9 = useValueNotifier(0, []);

            useEffect(() {
              print('\$val1\$val2\$val3\$val4\$val5\$val6\$val7\$val8\$val9');
            }, []);

            return Text('TestWidget');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, []);
    });

    test('ignore hooks without keys', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
          }): super(key: key);

          @override
          Widget build(BuildContext context) {
            final val1 = useAnimationController();
            final val2 = usePageController();
            final val3 = useScrollController();
            final val4 = useSingleTickerProvider();
            final val5 = useStreamController();
            final val6 = useTabController();
            final val7 = useTransformationController();
            final val8 = useMemoized(() => dep);
            final val9 = useValueNotifier(0);

            useEffect(() {
              print('\$val1\$val2\$val3\$val4\$val5\$val6\$val7\$val8\$val9');
            }, []);

            return Text('TestWidget');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, []);
    });

    test('report useCallback', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.dep,
          }): super(key: key);

          final String dep;

          @override
          Widget build(BuildContext context) {
            final test = useCallback(() {
              print(dep);
            }, []);

            return Text('TestWidget');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, [_FoundKey('dep', 'class field')]);
    });

    test('report hooks in a custom hook', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
          }): super(key: key);

          @override
          Widget build(BuildContext context) {
            final test = useHook('Hello');

            return Text(test);
          }
        }

        String useHook(String value) {
          final length = value.length;
          return useMemoized(() => 'value: ' + value + ' length: ' + length, []);
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, [
        _FoundKey('value', 'function parameter'),
        _FoundKey('length', 'local variable'),
      ]);
    });

    test('report complex dotted value', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.controller,
          }) : super(key: key);

          final StreamController<String> controller;

          @override
          Widget build(BuildContext context) {
            useEffect(() {
              final subscription = controller.stream
                  .listen(
                     (e) => Future.microtask(
                       () => print(e),
                     ),
                  );

              return subscription.cancel;
            }, []);

            return Text('Hello');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, [_FoundKey('controller', 'class field')]);
    });

    test('report optional dotted value', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            this.list,
          }) : super(key: key);

          final List<String>? list;

          @override
          Widget build(BuildContext context) {
            useEffect(() {
              print(list?.length);
            }, []);

            return Text('Hello');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, [_FoundKey('list', 'class field')]);
    });

    test('ignore value notifier', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            this.flag,
          }) : super(key: key);

          final ValueNotifier<bool> flag;

          @override
          Widget build(BuildContext context) {
            useEffect(() {
              flag.value = true;
            }, [flag.value]);

            return Text('Hello');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, []);
    });

    test('ignore useState value reference', () async {
      final source = '''
        class TestWidget extends HookWidget {
          @override
          Widget build(BuildContext context) {
            final state = useState(0);

            useEffect(() {
              state.value++;
            }, []);

            return Text(
              '\${state.value}',
            );
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, []);
    });

    test('ignore default constantHooks value reference', () async {
      final source = '''
        class TestWidget extends HookWidget {
          @override
          Widget build(BuildContext _) {
            final context = useContext();
            final state = useRef(0);
            final isMounted = useIsMounted();

            useEffect(() {
              state.value++;

              if (isMounted) {
                print('mounted');
              }

              print(context.toString());
            }, []);

            return Text('Hello');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, []);
    });

    test('ignore option specified constantHooks value reference', () async {
      final source = '''
        class TestWidget extends HookWidget {
          @override
          Widget build(BuildContext _) {
            final constant = useCustomHook();

            useEffect(() {
              print(constant.toString());
            }, []);

            return Text('Hello');
          }
        }
      ''';

      final keys = await _findMissingKeys(
        source,
        ExhaustiveKeysOptions(
          constantHooks: [
            'useCustomHook',
          ],
        ),
      );

      expect(keys, []);
    });

    test('ignore local const reference', () async {
      final source = '''
        class TestWidget extends HookWidget {
          @override
          Widget build(BuildContext context) {
            const state = 'CONSTANT';

            useEffect(() {
              print(state);
            }, []);

            return Text('Hello');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, []);
    });

    test('ignore top-level const reference', () async {
      final source = '''
        const value = 'CONSTANT';

        class TestWidget extends HookWidget {
          @override
          Widget build(BuildContext context) {
            useEffect(() {
              print(value);
            }, []);

            return Text('Hello');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, []);
    });

    test('ignore library reference', () async {
      final source = '''
        import 'dart:math';

        class TestWidget extends HookWidget {
          @override
          Widget build(BuildContext context) {
            useEffect(() {
              print('\$pi');
            }, []);

            return Text('Hello');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, []);
    });
  });

  group('unnecessary keys', () {
    test('report unused variable reference', () async {
      final source = '''
        import 'dart:math';
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
          }): super(key: key);
          @override
          Widget build(BuildContext context) {
            final dep = Random();
            useEffect(() {
              print('Hello');
            }, [dep]);
            return Text('TestWidget');
          }
        }
      ''';

      final keys = await _findUnnecessaryKeys(source);

      expect(keys, [_FoundKey('dep', 'local variable')]);
    });

    test('report useState notifier reference', () async {
      final source = '''
        class TestWidget extends HookWidget {
          @override
          Widget build(BuildContext context) {
            final state = useState(0);
            useEffect(() {
              state.value++;
            }, [state]);
            return Text(
              '\${state.value}',
            );
          }
        }
      ''';

      final keys = await _findUnnecessaryKeys(source);

      expect(keys, [_FoundKey('state', 'state variable')]);
    });

    test('ignore useState value reference', () async {
      final source = '''
        class TestWidget extends HookWidget {
          @override
          Widget build(BuildContext context) {
            final state = useState(0);
            useEffect(() {
              if (state.value == 0) {
                print('Hello');
              }
            }, [state.value]);
            return Text(
              '\${state.value}',
            );
          }
        }
      ''';

      final keys = await _findUnnecessaryKeys(source);

      expect(keys, []);
    });

    test('ignore dotted value', () async {
      final source = '''
        const _limit = 5;

        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            this.list,
          }) : super(key: key);

          final List<String> list;

          @override
          Widget build(BuildContext context) {
            final state = useState(0);
            useEffect(() {
              state.value = list.length <= _limit;
            }, [list.length]);
            return Text('Hello');
          }
        }
      ''';

      final keys = await _findUnnecessaryKeys(source);

      expect(keys, []);
    });

    test('ignore complex dotted value', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.controller,
          }) : super(key: key);

          final StreamController<String> controller;

          @override
          Widget build(BuildContext context) {
            useEffect(() {
              final subscription = controller.stream
                  .listen(
                     (e) => Future.microtask(
                       () => print(e),
                     ),
                  );

              return subscription.cancel;
            }, [controller]);

            return Text('Hello');
          }
        }
      ''';

      final keys = await _findUnnecessaryKeys(source);

      expect(keys, []);
    });

    test('ignore optional dotted value exists in keys full expression',
        () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            this.list,
          }) : super(key: key);

          final List<String>? list;

          @override
          Widget build(BuildContext context) {
            useEffect(() {
              print(list?.length);
            }, [list?.length]);

            return Text('Hello');
          }
        }
      ''';

      final keys = await _findUnnecessaryKeys(source);

      expect(keys, []);
    });

    test('ignore optional dotted value exists in keys short expression',
        () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            this.list,
          }) : super(key: key);

          final List<String>? list;

          @override
          Widget build(BuildContext context) {
            useEffect(() {
              print(list?.length);
            }, [list]);

            return Text('Hello');
          }
        }
      ''';

      final keys = await _findUnnecessaryKeys(source);

      expect(keys, []);
    });
  });

  group('function keys', () {
    test('report', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
          }) : super(key: key);

          @override
          Widget build(BuildContext context) {
            void listener() {
              print('hello');
            }

            useEffect(() {
              listener();
            }, [listener]);

            return Text('Hello');
          }
        }
      ''';

      final keys = await _findFunctionKeys(source);

      expect(keys, [_FoundKey('listener', 'local function')]);
    });
  });
}
