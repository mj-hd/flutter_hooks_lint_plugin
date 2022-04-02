import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/hook_widget_visitor.dart';
import 'package:flutter_hooks_lint_plugin/src/lint/utils/lint_error.dart';
import 'package:logging/logging.dart';

final log = Logger('rules_of_hooks');

void findRulesOfHooks(
  CompilationUnit unit, {
  required void Function(LintError) onReport,
}) {
  log.finer('findRulesOfHooks');

  unit.visitChildren(
    HookWidgetVisitor(
      contextBuilder: () => _Context(),
      onBuildBlock: (_Context context, node, _) {
        node.visitChildren(
          _HooksInvocationVisitor(
            context: context,
            onReport: onReport,
          ),
        );
      },
    ),
  );
}

class LintErrorNestedHooks extends LintError {
  static const _nestedHooksCode = 'nested_hooks';

  LintErrorNestedHooks(this.hookName, AstNode errNode)
      : super(
          message:
              'Avoid nested use of $hookName. Hooks must be used in top-level scope of the build function.',
          code: _nestedHooksCode,
          errNode: errNode,
        );

  final String hookName;
}

class _Context {}

class _HooksInvocationVisitor extends RecursiveAstVisitor<void> {
  _HooksInvocationVisitor({
    required this.context,
    required this.onReport,
  });

  final _Context context;
  final void Function(LintError) onReport;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!node.methodName.name.startsWith('use')) {
      node.visitChildren(_HooksInvocationVisitor(
        context: context,
        onReport: onReport,
      ));
      return;
    }

    log.finer('_HooksInvocationVisitor: visit($node)');

    if (_findControlFlow(node.parent)) {
      onReport(LintErrorNestedHooks(node.methodName.name, node));
    }
  }

  bool _findControlFlow(AstNode? node) {
    log.finest('_HooksInvocationVisitor: _findControlFlow($node)');

    if (node == null) return false;
    if (node is MethodDeclaration && node.name.name == 'build') {
      return false;
    }

    if (node is IfStatement) return true;
    if (node is ForStatement) return true;
    if (node is SwitchStatement) return true;
    if (node is WhileStatement) return true;
    if (node is DoStatement) return true;
    if (node is FunctionDeclarationStatement) return true;
    if (node is MethodInvocation &&
        (node.staticType?.isDartCoreIterable ?? false)) return true;
    if (node is MethodInvocation && node.methodName.name == 'assert') {
      return true;
    }

    return _findControlFlow(node.parent);
  }
}
