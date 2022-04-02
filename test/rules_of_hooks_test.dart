import 'package:flutter_hooks_lint_plugin/src/lint/rules_of_hooks.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/utils/lint_error.dart';
import 'package:test/test.dart';

import 'matcher.dart';
import 'utils.dart';

Future<LintError?> _findError(String source) async {
  final unit = await compileCode(source);

  LintError? result;

  findRulesOfHooks(
    unit,
    onReport: (err) {
      result = err;
    },
  );

  return result;
}

void main() {
  setUpLogging();

  group('rules of hooks', () {
    test('report use of useEffect inside an if-statement', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.param,
          }): super(key: key);

          final bool param;

          @override
          Widget build(BuildContext context) {
            if (param) {
              useEffect(() {
                print(param);
              }, [param]);
            }

            return Text('TestWidget');
          }
        }
      ''';

      final error = await _findError(source);

      expect(error, LintErrorNestedHooksMatcher('useEffect'));
    });

    test('report use of useEffect inside a block omitted if-statement',
        () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.param,
          }): super(key: key);

          final bool param;

          @override
          Widget build(BuildContext context) {
            if (param) useEffect(() { print(param); }, [param]);

            return Text('TestWidget');
          }
        }
      ''';

      final error = await _findError(source);

      expect(error, LintErrorNestedHooksMatcher('useEffect'));
    });

    test('report use of useEffect inside a switch-statement', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.param,
          }): super(key: key);

          final String param;

          @override
          Widget build(BuildContext context) {
            switch (param) {
              case 'hello':
                useEffect(() {
                  print(param);
                }, [param]);
                break;
            }

            return Text('TestWidget');
          }
        }
      ''';

      final error = await _findError(source);

      expect(error, LintErrorNestedHooksMatcher('useEffect'));
    });

    test('report use of useEffect inside a for-statement', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.param,
          }): super(key: key);

          final List<String> param;

          @override
          Widget build(BuildContext context) {
            for (final p in param) {
              useEffect(() {
                print(p);
              }, [p]);
            }

            return Text('TestWidget');
          }
        }
      ''';

      final error = await _findError(source);

      expect(error, LintErrorNestedHooksMatcher('useEffect'));
    });

    test('report use of useEffect inside a while-statement', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.param,
          }): super(key: key);

          final List<String> param;

          @override
          Widget build(BuildContext context) {
            while (true) {
              useEffect(() {
                print(p);
              }, [p]);
            }

            return Text('TestWidget');
          }
        }
      ''';

      final error = await _findError(source);

      expect(error, LintErrorNestedHooksMatcher('useEffect'));
    });

    test('report use of useEffect inside a do-statement', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.param,
          }): super(key: key);

          final List<String> param;

          @override
          Widget build(BuildContext context) {
            do {
              useEffect(() {
                print(p);
              }, [p]);
            } while (true);

            return Text('TestWidget');
          }
        }
      ''';

      final error = await _findError(source);

      expect(error, LintErrorNestedHooksMatcher('useEffect'));
    });

    test('report use of useEffect with iterable', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.param,
          }): super(key: key);

          final List<String?> param;

          @override
          Widget build(BuildContext context) {
            param.whereType<String>().map((e) => useEffect(() {
              print(e);
            }, [e]));

            return Text('TestWidget');
          }
        }
      ''';

      final error = await _findError(source);

      expect(error, LintErrorNestedHooksMatcher('useEffect'));
    });

    test('report use of useEffect inside a function declaration', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.param,
          }): super(key: key);

          final List<String?> param;

          @override
          Widget build(BuildContext context) {
            void effect() {
              useEffect(() {
                print(e);
              }, [e]));
            }

            effect();

            return Text('TestWidget');
          }
        }
      ''';

      final error = await _findError(source);

      expect(error, LintErrorNestedHooksMatcher('useEffect'));
    });

    test('ignore top-level use of useEffect', () async {
      final source = '''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.param,
          }): super(key: key);

          final bool param;

          @override
          Widget build(BuildContext context) {
            if (param) {
              print('not related code');
            }

            useEffect(() {
              print(param);
            }, [param]);

            return Text('TestWidget');
          }
        }
      ''';

      final error = await _findError(source);

      expect(error, isNull);
    });
  });
}
