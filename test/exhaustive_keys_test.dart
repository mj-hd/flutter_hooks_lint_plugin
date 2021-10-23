import 'package:analyzer/dart/element/element.dart';
import 'package:flutter_hooks_lint_plugin/src/plugin/exhaustive_keys.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import 'utils.dart';

Future<Tuple2<List<Element>?, List<Element>?>> _find(String source) async {
  final unit = await compileCode(source);

  var missingKeys;
  var unnecessaryKeys;

  findExhaustiveKeys(
    unit,
    onMissingKeysReport: (keys, node) {
      missingKeys = keys;
    },
    onUnnecessaryKeysReport: (keys, node) {
      unnecessaryKeys = keys;
    },
  );

  return Tuple2(missingKeys, unnecessaryKeys);
}

Future<List<Element>?> _findMissingKeys(String source) async {
  return (await _find(source)).item1;
}

Future<List<Element>?> _findUnnecessaryKeys(String source) async {
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

      expect(keys, isNotNull);
      expect(keys!.length, 1);
      expect(keys[0].name, 'dep');
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

      expect(keys, isNotNull);
      expect(keys!.length, 1);
      expect(keys[0].name, 'dep');
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

      expect(keys, isNull);
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

      expect(keys, isNull);
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

      expect(keys, isNull);
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

      expect(keys, isNull);
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

      expect(keys, isNull);
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

      expect(keys, isNotNull);
      expect(keys!.length, 1);
      expect(keys[0].name, 'dep');
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

      expect(keys, isNotNull);
      expect(keys!.length, 1);
      expect(keys[0].name, 'state');
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

      expect(keys, isNull);
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

      expect(keys, isNotNull);
      expect(keys!.length, 1);
      expect(keys[0].name, 'state');
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

      expect(keys, isNull);
    });
  });
}
