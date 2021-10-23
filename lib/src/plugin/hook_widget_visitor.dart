import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:logging/logging.dart';

final log = Logger('hook_widget_visitor');

extension AstNodeFindChild on AstNode {
  T? findChild<T extends AstNode>() {
    final nodes = childEntities.whereType<T>();

    if (nodes.isEmpty) return null;

    return nodes.first;
  }
}

class HookWidgetVisitor<C> extends SimpleAstVisitor<void> {
  HookWidgetVisitor(
    this.context, {
    this.onClassDeclaration,
    this.onBuildBlock,
  });

  final C context;
  final void Function(C context, ClassDeclaration node)? onClassDeclaration;
  final void Function(C context, Block node, ExecutableElement? elem)?
      onBuildBlock;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    log.finer('HookWidgetVisitor: visit($node)');

    switch (node.extendsClause?.superclass.name.name) {
      case 'HookWidget':
      case 'HookConsumerWidget':
        onClassDeclaration?.call(context, node);

        if (onBuildBlock != null) {
          node.visitChildren(_BuildVisitor(context, onBuildBlock!));
        }
    }
  }
}

class _BuildVisitor<C> extends SimpleAstVisitor<void> {
  _BuildVisitor(
    this.context,
    this.visitHandler,
  );

  final C context;
  final void Function(C context, Block node, ExecutableElement? elem)
      visitHandler;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.name != 'build') return;

    log.finer('_BuildVisitor: visit($node)');

    final block = node.findChild<BlockFunctionBody>()?.findChild<Block>();

    if (block == null) return;

    visitHandler(context, block, node.declaredElement);
  }
}
