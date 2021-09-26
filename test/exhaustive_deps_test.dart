import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_hooks_lint_plugin/src/plugin/exhaustive_deps.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import 'utils.dart';

Future<Tuple2<List<Identifier>?, List<Identifier>?>> _find(
    String source) async {
  final unit = await compileCode(source);

  var missingDeps;
  var unnecessaryDeps;

  findExhaustiveDeps(
    unit,
    onMissingDepsReport: (deps, node) {
      missingDeps = deps;
    },
    onUnnecessaryDepsReport: (deps, node) {
      unnecessaryDeps = deps;
    },
  );

  return Tuple2(missingDeps, unnecessaryDeps);
}

Future<List<Identifier>?> _findMissingDeps(String source) async {
  return (await _find(source)).item1;
}

Future<List<Identifier>?> _findUnnecessaryDeps(String source) async {
  return (await _find(source)).item2;
}

void main() {
  setUpLogging();

  group('exhaustive deps', () {
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

      final deps = await _findMissingDeps(source);

      expect(deps, isNotNull);
      expect(deps!.length, 1);
      expect(deps[0].name, 'dep');
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

      final deps = await _findMissingDeps(source);

      expect(deps, isNotNull);
      expect(deps!.length, 1);
      expect(deps[0].name, 'dep');
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

      final deps = await _findMissingDeps(source);

      expect(deps, isNull);
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

      final deps = await _findMissingDeps(source);

      expect(deps, isNull);
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

      final deps = await _findMissingDeps(source);

      expect(deps, isNull);
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

      final deps = await _findMissingDeps(source);

      expect(deps, isNull);
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

      final deps = await _findMissingDeps(source);

      expect(deps, isNull);
    });
  });
}
