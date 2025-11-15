import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:logging/logging.dart';

final log = Logger('hook_widget_visitor');

extension AstNodeFindChild on AstNode {
  T? findChild<T extends AstNode>() {
    final nodes = childEntities.whereType<T>();

    if (nodes.isEmpty) return null;

    return nodes.first;
  }
}

class HookBlockVisitor extends SimpleAstVisitor<void> {
  HookBlockVisitor({
    this.onClassDeclaration,
    this.onFormalParametersList,
    this.onBuildBlock,
  });

  final void Function(ClassDeclaration node)? onClassDeclaration;
  final void Function(FormalParameterList node)? onFormalParametersList;
  final void Function(Block node)? onBuildBlock;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    log.finer('HookWidgetVisitor: visit($node)');

    switch (node.extendsClause?.superclass.name.lexeme) {
      case 'HookWidget':
      case 'HookConsumerWidget':
        onClassDeclaration?.call(node);

        if (onBuildBlock != null) {
          node.visitChildren(_BuildVisitor(onBuildBlock!));
        }
    }
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (!node.name.lexeme.startsWith('use') &&
        !node.name.lexeme.startsWith('_use')) {
      return;
    }

    log.finer('CustomHookFunctionVisitor: visit($node)');

    final expr = node.functionExpression;
    final block = expr.findChild<BlockFunctionBody>()?.findChild<Block>();

    if (block == null) return;

    if (expr.parameters != null) {
      onFormalParametersList?.call(expr.parameters!);
    }
    onBuildBlock?.call(block);
  }
}

class _BuildVisitor extends SimpleAstVisitor<void> {
  _BuildVisitor(this.visitHandler);

  final void Function(Block node) visitHandler;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme != 'build') return;

    log.finer('_BuildVisitor: visit($node)');

    final block = node.findChild<BlockFunctionBody>()?.findChild<Block>();

    if (block == null) return;

    visitHandler(block);
  }
}
