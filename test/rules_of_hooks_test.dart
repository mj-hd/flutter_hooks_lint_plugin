// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_hooks_lint_plugin/main.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/rules_of_hooks.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'utils.dart';

void main() {
  setUpLogging();
  defineReflectiveSuite(() {
    defineReflectiveTests(RulesOfHooksRuleTest);
  });
}

@reflectiveTest
class RulesOfHooksRuleTest extends AnalysisRuleTest {
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
    WarningCode.deadCode,
    ...super.ignoredDiagnosticCodes,
  ];

  @override
  void setUp() {
    final pluginContext = FlutterHooksLintPluginContext();
    rule = RulesOfHooksRule(pluginContext);
    super.setUp();
  }

  void test_use_of_useEffect_inside_an_if_statement() async {
    await assertDiagnostics(
      '''
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
      ''',
      [lint(297, 70, name: RulesOfHooksRule.codeForNestedHooks.name)],
    );
  }

  void test_use_of_useEffect_inside_a_block_omitted_if_statement() async {
    await assertDiagnostics(
      '''
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
      ''',
      [lint(281, 40, name: RulesOfHooksRule.codeForNestedHooks.name)],
    );
  }

  void test_report_use_of_useEffect_inside_a_switch_statement() async {
    await assertDiagnostics(
      '''
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
      ''',
      [lint(333, 74, name: RulesOfHooksRule.codeForNestedHooks.name)],
    );
  }

  void test_report_use_of_useEffect_inside_a_for_statement() async {
    await assertDiagnostics(
      '''
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
      ''',
      [lint(317, 62, name: RulesOfHooksRule.codeForNestedHooks.name)],
    );
  }

  void test_report_use_of_useEffect_inside_a_while_statement() async {
    await assertDiagnostics(
      '''
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
                print(param);
              }, [param]);
            }

            return Text('TestWidget');
          }
        }
      ''',
      [lint(307, 70, name: RulesOfHooksRule.codeForNestedHooks.name)],
    );
  }

  void test_report_use_of_useEffect_inside_a_do_statement() async {
    await assertDiagnostics(
      '''
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
                print(param);
              }, [param]);
            } while (true);

            return Text('TestWidget');
          }
        }
      ''',
      [lint(297, 70, name: RulesOfHooksRule.codeForNestedHooks.name)],
    );
  }

  void test_report_use_of_useEffect_with_iterable() async {
    await assertDiagnostics(
      '''
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
      ''',
      [lint(316, 58, name: RulesOfHooksRule.codeForNestedHooks.name)],
    );
  }

  void test_report_use_of_useEffect_inside_a_function_declaration() async {
    await assertDiagnostics(
      '''
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
                print(param);
              }, [param]);
            }

            effect();

            return Text('TestWidget');
          }
        }
      ''',
      [lint(309, 70, name: RulesOfHooksRule.codeForNestedHooks.name)],
    );
  }

  void test_ignore_top_level_use_of_useEffect() async {
    await assertNoDiagnostics('''
        class TestWidget extends HookWidget {
          const TestWidget({
            Key? key,
            required this.param,
          }): super(key: key);

          final bool param;

          @override
          Widget build(BuildContext context) {
            if (param) {
              print('non related code');
            }

            useEffect(() {
              print(param);
            }, [param]);

            return Text('TestWidget');
          }
        }
      ''');
  }
}
