import 'package:flutter_hooks_lint_plugin/src/plugin/exhaustive_keys.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import 'utils.dart';

Future<Tuple2<List<String>, List<String>>> _find(String source) async {
  final unit = await compileCode(source);

  var missingKeys = <String>[];
  var unnecessaryKeys = <String>[];

  findExhaustiveKeys(
    unit,
    onMissingKeyReport: (key, node) {
      missingKeys.add(key);
    },
    onUnnecessaryKeyReport: (key, node) {
      unnecessaryKeys.add(key);
    },
  );

  return Tuple2(missingKeys, unnecessaryKeys);
}

Future<List<String>> _findMissingKeys(String source) async {
  return (await _find(source)).item1;
}

Future<List<String>> _findUnnecessaryKeys(String source) async {
  return (await _find(source)).item2;
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

      expect(keys, ['dep']);
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

      expect(keys, ['dep']);
    });

    test('report useMemoized', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.dep,
          }): super(key: key);

          final String dep;

          @override
          Widget build(BuildContext context) {
            final test = useMemoized(() => dep, []);

            return Text('TestWidget');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

      expect(keys, ['dep']);
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

      expect(keys, ['dep']);
    });

    test('report complex dotted value', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
          }) : super(key: key);

          @override
          Widget build(BuildContext context) {
            final streamController = useStreamController();

            useEffect(() {
              final subscription = streamController.stream
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

      expect(keys, ['streamController']);
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

      expect(keys, ['list']);
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

    test('ignore useRef value reference', () async {
      final source = '''
        class TestWidget extends HookWidget {
          @override
          Widget build(BuildContext context) {
            final state = useRef(0);

            useEffect(() {
              state.value++;
            }, []);

            return Text('Hello');
          }
        }
      ''';

      final keys = await _findMissingKeys(source);

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

      expect(keys, ['dep']);
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

      expect(keys, ['state']);
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

    test('report useRef value reference', () async {
      final source = '''
        class TestWidget extends HookWidget {
          @override
          Widget build(BuildContext context) {
            final state = useRef(0);
            useEffect(() {
              state.value++;
            }, [state]);
            return Text('Hello');
          }
        }
      ''';

      final keys = await _findUnnecessaryKeys(source);

      expect(keys, ['state']);
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
          }) : super(key: key);

          @override
          Widget build(BuildContext context) {
            final streamController = useStreamController();

            useEffect(() {
              final subscription = streamController.stream
                  .listen(
                     (e) => Future.microtask(
                       () => print(e),
                     ),
                  );

              return subscription.cancel;
            }, [streamController]);

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
}
