import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:flutter_hooks_lint_plugin/main.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/hook_widget_visitor.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/lint_error.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/supression.dart';
import 'package:logging/logging.dart';

final log = Logger('rules_of_hooks');

class RulesOfHooksRule extends MultiAnalysisRule {
  static const rulesOfHooksName = 'nested_hooks';
  static const codeForNestedHooks = LintCode(
    rulesOfHooksName,
    'Avoid nested use of {0}. Hooks must be used in top-level scope of the build function.',
  );

  RulesOfHooksRule(this.pluginContext)
    : super(
        name: rulesOfHooksName,
        description: 'Rule for enforcing correct usage of hooks',
      );

  final FlutterHooksLintPluginContext pluginContext;

  @override
  List<DiagnosticCode> get diagnosticCodes => const [codeForNestedHooks];

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    log.finer('findRulesOfHooks');

    registry.addClassDeclaration(
      this,
      HookBlockVisitor(
        onBuildBlock: (node) {
          node.visitChildren(
            _HooksInvocationVisitor(
              onReport: (error) {
                final suppression = Suppression.fromCache(
                  context.currentUnit!.content,
                );
                if (suppression.isSuppressedLintError(error)) return;
                reportAtNode(
                  error.errNode,
                  diagnosticCode: error.code,
                  arguments: [
                    if (error.errNode is MethodInvocation)
                      (error.errNode as MethodInvocation).methodName.toString(),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _HooksInvocationVisitor extends RecursiveAstVisitor<void> {
  _HooksInvocationVisitor({required this.onReport});

  final void Function(LintError) onReport;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!node.methodName.name.startsWith('use')) {
      node.visitChildren(_HooksInvocationVisitor(onReport: onReport));
      return;
    }

    log.finer('_HooksInvocationVisitor: visit($node)');

    if (_findControlFlow(node.parent)) {
      onReport(
        LintError(code: RulesOfHooksRule.codeForNestedHooks, errNode: node),
      );
    }
  }

  bool _findControlFlow(AstNode? node) {
    log.finest('_HooksInvocationVisitor: _findControlFlow($node)');

    if (node == null) return false;
    if (node is MethodDeclaration && node.name.lexeme == 'build') {
      return false;
    }

    if (node is IfStatement) return true;
    if (node is ForStatement) return true;
    if (node is SwitchStatement) return true;
    if (node is WhileStatement) return true;
    if (node is DoStatement) return true;
    if (node is FunctionDeclarationStatement) return true;
    if (node is MethodInvocation &&
        (node.staticType?.isDartCoreIterable ?? false)) {
      return true;
    }
    if (node is MethodInvocation && node.methodName.name == 'assert') {
      return true;
    }

    return _findControlFlow(node.parent);
  }
}
