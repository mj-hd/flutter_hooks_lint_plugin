import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_hooks_lint_plugin/src/plugin/hook_widget_visitor.dart';
import 'package:logging/logging.dart';

final log = Logger('rules_of_hooks');

void findRulesOfHooks(
  CompilationUnit unit, {
  required void Function(String, AstNode) onNestedHooksReport,
}) {
  log.finer('findRulesOfHooks');

  unit.visitChildren(
    HookWidgetVisitor(
      contextBuilder: () => _Context(),
      onBuildBlock: (_Context context, node, _) {
        node.visitChildren(
          _HooksInvocationVisitor(
            context: context,
            onNestedHooksReport: onNestedHooksReport,
          ),
        );
      },
    ),
  );
}

class _Context {}

class _HooksInvocationVisitor extends RecursiveAstVisitor<void> {
  _HooksInvocationVisitor({
    required this.context,
    required this.onNestedHooksReport,
  });

  final _Context context;
  final void Function(String, AstNode) onNestedHooksReport;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!node.methodName.name.startsWith('use')) {
      node.visitChildren(_HooksInvocationVisitor(
        context: context,
        onNestedHooksReport: onNestedHooksReport,
      ));
      return;
    }

    log.finer('_HooksInvocationVisitor: visit($node)');

    if (_findControlFlow(node.parent)) {
      onNestedHooksReport(node.methodName.name, node);
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
