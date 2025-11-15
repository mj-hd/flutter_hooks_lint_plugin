// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_hooks_lint_plugin/main.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/exhaustive_keys.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'utils.dart';

void main() {
  setUpLogging();
  defineReflectiveSuite(() {
    defineReflectiveTests(ExhaustiveKeysRuleTest);
  });
}

@reflectiveTest
class ExhaustiveKeysRuleTest extends AnalysisRuleTest {
  @override
  final bool addFlutterPackageDep = false; // See: https://github.com/dart-lang/sdk/issues/61597

  @override
  List<DiagnosticCode> get ignoredDiagnosticCodes => [
    CompileTimeErrorCode.undefinedMethod,
    CompileTimeErrorCode.undefinedNamedParameter,
    CompileTimeErrorCode.undefinedClass,
    CompileTimeErrorCode.undefinedFunction,
    CompileTimeErrorCode.argumentTypeNotAssignable,
    CompileTimeErrorCode.extendsNonClass,
    WarningCode.bodyMightCompleteNormallyNullable,
    WarningCode.overrideOnNonOverridingMethod,
    ...super.ignoredDiagnosticCodes,
  ];

  @override
  void setUp() {
    final pluginContext = FlutterHooksLintPluginContext();
    rule = ExhaustiveKeysRule(pluginContext);
    super.setUp();

    setupFlutterHooksStub();
  }

  void test_missing_keys_report_class_property_reference() async {
    await assertDiagnostics(
      '''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''',
      [lint(384, 2, name: ExhaustiveKeysRule.codeForMissingKey.name)],
    );
  }

  void test_missing_key_report_local_variabll_reference() async {
    await assertDiagnostics(
      '''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''',
      [lint(388, 2, name: ExhaustiveKeysRule.codeForMissingKey.name)],
    );
  }

  void test_missing_key_report_local_function_reference() async {
    await assertDiagnostics(
      '''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''',
      [lint(389, 2, name: ExhaustiveKeysRule.codeForMissingKey.name)],
    );
  }

  void test_missing_key_ignore_useEffect_without_keys() async {
    await assertNoDiagnostics('''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''');
  }

  void test_missing_key_report_hooks_with_keys() async {
    await assertDiagnostics(
      '''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''',
      [
        lint(961, 2, name: ExhaustiveKeysRule.codeForMissingKey.name),
        lint(961, 2, name: ExhaustiveKeysRule.codeForMissingKey.name),
        lint(961, 2, name: ExhaustiveKeysRule.codeForMissingKey.name),
        lint(961, 2, name: ExhaustiveKeysRule.codeForMissingKey.name),
        lint(961, 2, name: ExhaustiveKeysRule.codeForMissingKey.name),
        lint(961, 2, name: ExhaustiveKeysRule.codeForMissingKey.name),
        lint(961, 2, name: ExhaustiveKeysRule.codeForMissingKey.name),
        lint(961, 2, name: ExhaustiveKeysRule.codeForMissingKey.name),
        lint(961, 2, name: ExhaustiveKeysRule.codeForMissingKey.name),
      ],
    );
  }

  void test_missing_key_ignore_hooks_with_empty_keys() async {
    await assertNoDiagnostics('''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''');
  }

  void test_missing_key_ignore_hooks_without_keys() async {
    await assertNoDiagnostics('''
        import 'package:flutter_hooks/flutter_hooks.dart';

        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.dep,
          }): super(key: key);

          final bool dep;

          @override
          Widget build(BuildContext context) {
            final val1 = useAnimationController();
            final val2 = usePageController();
            final val3 = useScrollController();
            final val4 = useSingleTickerProvider();
            final val5 = useStreamController();
            final val6 = useTabController();
            final val7 = useTransformationController();
            final val8 = useValueNotifier(0);

            useEffect(() {
              print('\$val1\$val2\$val3\$val4\$val5\$val6\$val7\$val8');
            }, []);

            return Text('TestWidget');
          }
        }
      ''');
  }

  void test_missing_key_report_useCallback() async {
    await assertDiagnostics(
      '''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''',
      [lint(399, 2, name: ExhaustiveKeysRule.codeForMissingKey.name)],
    );
  }

  void test_missing_key_report_hooks_in_a_custom_hook() async {
    await assertDiagnostics(
      '''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''',
      [
        lint(509, 2, name: ExhaustiveKeysRule.codeForMissingKey.name),
        lint(509, 2, name: ExhaustiveKeysRule.codeForMissingKey.name),
      ],
    );
  }

  void test_missing_key_report_complex_dotted_value() async {
    await assertDiagnostics(
      '''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''',
      [lint(644, 2, name: ExhaustiveKeysRule.codeForMissingKey.name)],
    );
  }

  void test_missing_key_report_optional_dotted_value() async {
    await assertDiagnostics(
      '''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''',
      [lint(394, 2, name: ExhaustiveKeysRule.codeForMissingKey.name)],
    );
  }

  void test_missing_key_ignore_value_notifier() async {
    await assertNoDiagnostics('''
        import 'package:flutter_hooks/flutter_hooks.dart';

        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.flag,
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
      ''');
  }

  void test_missing_key_ignore_useState_value_reference() async {
    await assertNoDiagnostics('''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''');
  }

  void test_missing_key_ignore_default_constantHooks_value_reference() async {
    await assertNoDiagnostics('''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''');
  }

  void
  test_missing_key_ignore_option_specified_constantHooks_value_reference() async {
    await assertDiagnostics(
      '''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''',
      [lint(298, 2, name: ExhaustiveKeysRule.codeForMissingKey.name)],
    );
  }

  void test_missing_key_ignore_local_const_reference() async {
    await assertNoDiagnostics('''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''');
  }

  void test_missing_key_ignore_top_level_const_reference() async {
    await assertNoDiagnostics('''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''');
  }

  void test_missing_key_ignore_library_reference() async {
    await assertNoDiagnostics('''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''');
  }

  void test_missing_key_suggest_to_add_keys_param_with_leading_comma() async {
    await assertDiagnostics(
      '''
        import 'package:flutter_hooks/flutter_hooks.dart';

        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.dep,
          }): super(key: key);

          final String dep;

          @override
          Widget build(BuildContext context) {
            final test = useMemoized(() {
              return dep;
            });

            return Text(test);
          }
        }
      ''',
      [lint(341, 11, name: ExhaustiveKeysRule.codeForMissingKey.name)],
    );
  }

  void test_missing_key_suggest_to_add_keys_param_with_trailing_comma() async {
    await assertDiagnostics(
      '''
        import 'package:flutter_hooks/flutter_hooks.dart';

        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.dep,
          }): super(key: key);

          final String dep;

          @override
          Widget build(BuildContext context) {
            final test = useMemoized(
              () {
                return dep;
              },
            );

            return Text(test);
          }
        }
      ''',
      [lint(341, 11, name: ExhaustiveKeysRule.codeForMissingKey.name)],
    );
  }

  void test_missing_key_suggest_to_append_key_with_leading_comma() async {
    await assertDiagnostics(
      '''
        import 'package:flutter_hooks/flutter_hooks.dart';

        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.dep1,
            required this.dep2,
          }): super(key: key);

          final String dep1;
          final String dep2;

          @override
          Widget build(BuildContext context) {
            useEffect(() {
              print(dep1 + dep2);
            }, [dep1]);

            return Text('TestWidget');
          }
        }
      ''',
      [lint(455, 6, name: ExhaustiveKeysRule.codeForMissingKey.name)],
    );
  }

  void test_missing_key_suggest_to_append_key_with_trailing_comma() async {
    await assertDiagnostics(
      '''
        import 'package:flutter_hooks/flutter_hooks.dart';

        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.dep1,
            required this.dep2,
          }): super(key: key);

          final String dep1;
          final String dep2;

          @override
          Widget build(BuildContext context) {
            useEffect(() {
              print(dep1 + dep2);
            }, [
              dep1,
            ]);

            return Text('TestWidget');
          }
        }
      ''',
      [lint(455, 35, name: ExhaustiveKeysRule.codeForMissingKey.name)],
    );
  }

  void test_unnecessary_report_unused_variable_reference() async {
    await assertDiagnostics(
      '''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''',
      [lint(389, 5, name: ExhaustiveKeysRule.codeForUnnecessaryKey.name)],
    );
  }

  void test_unnecessary_report_useState_notifier_reference() async {
    await assertDiagnostics(
      '''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''',
      [lint(283, 7, name: ExhaustiveKeysRule.codeForUnnecessaryKey.name)],
    );
  }

  void test_unnecessary_ignore_useState_value_reference() async {
    await assertDiagnostics('''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''', []);
  }

  void test_unnecessary_ignore_dotted_value() async {
    await assertDiagnostics('''
        import 'package:flutter_hooks/flutter_hooks.dart';

        const _limit = 5;

        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.list,
          }) : super(key: key);

          final List<String> list;

          @override
          Widget build(BuildContext context) {
            final state = useState(false);
            useEffect(() {
              state.value = list.length <= _limit;
            }, [list.length]);
            return Text('Hello');
          }
        }
      ''', []);
  }

  void test_unnecessary_ignore_complex_dotted_value() async {
    await assertDiagnostics('''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''', []);
  }

  void
  test_unnecessary_ignore_optional_dotted_value_exists_in_keys_full_expression() async {
    await assertDiagnostics('''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''', []);
  }

  void
  test_unnecessary_ignore_optional_dotted_value_exists_in_keys_short_expression() async {
    await assertDiagnostics('''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''', []);
  }

  void test_function_report() async {
    await assertDiagnostics(
      '''
        import 'package:flutter_hooks/flutter_hooks.dart';

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
      ''',
      [lint(400, 10, name: ExhaustiveKeysRule.codeForFunctionKey.name)],
    );
  }
}
