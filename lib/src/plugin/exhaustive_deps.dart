import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:logging/logging.dart';

final log = Logger('exhaustive_deps');

void findExhaustiveDeps(
  CompilationUnit unit, {
  required Function(List<Identifier>, AstNode) onMissingDepsReport,
  required Function(List<Identifier>, AstNode) onUnnecessaryDepsReport,
}) {
  log.finer('findExhaustiveDeps');

  final context = _Context();

  unit.visitChildren(
    _HookWidgetVisitor(
      context: context,
      onMissingDepsReport: onMissingDepsReport,
      onUnnecessaryDepsReport: onUnnecessaryDepsReport,
    ),
  );
}

extension on Identifier {
  bool equalsByStaticElement(Identifier other) {
    if (staticElement == null) return false;

    return staticElement?.id == other.staticElement?.id;
  }

  bool equalsByName(Identifier other) {
    return name == other.name;
  }
}

extension on AstNode {
  T? findChild<T extends AstNode>() {
    final nodes = childEntities.whereType<T>();

    if (nodes.isEmpty) return null;

    return nodes.first;
  }
}

class _Context {
  final List<Identifier> _localVariables = [];
  final List<Identifier> _classFields = [];

  void addLocalVariable(Identifier ident) {
    log.finer('_Context: addLocalVariable($ident)');

    _localVariables.add(ident);
  }

  void addClassField(Identifier ident) {
    log.finer('_Context: addClassVariable($ident)');

    _classFields.add(ident);
  }

  bool isVarialbe(Identifier ident) {
    log.finer('_Context: isVariable($ident)');

    if (_localVariables.any(ident.equalsByStaticElement)) {
      log.finest('_Context: isVariable($ident) => local variable');
      return true;
    }

    if (_classFields.any(ident.equalsByName)) {
      log.finest('_Context: isVariable($ident) => class field');
      return true;
    }

    log.finest('_Context: isVariable($ident) => not variable');
    return false;
  }
}

class _HookWidgetVisitor extends SimpleAstVisitor<void> {
  _HookWidgetVisitor({
    required this.context,
    required this.onMissingDepsReport,
    required this.onUnnecessaryDepsReport,
  });

  final _Context context;
  final Function(List<Identifier>, AstNode) onMissingDepsReport;
  final Function(List<Identifier>, AstNode) onUnnecessaryDepsReport;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    log.finer('_HookWidgetVisitor: visit($node)');

    switch (node.extendsClause?.superclass.name.name) {
      case 'HookWidget':
      case 'HookConsumerWidget':
        final fieldDeclarationVisitor = _FieldDeclarationVisitor(
          context: context,
        );

        node.visitChildren(fieldDeclarationVisitor);

        final buildVisitor = _BuildVisitor(
          context: context,
          onMissingDepsReport: onMissingDepsReport,
          onUnnecessaryDepsReport: onUnnecessaryDepsReport,
        );

        node.visitChildren(buildVisitor);
    }
  }
}

class _FieldDeclarationVisitor extends SimpleAstVisitor<void> {
  _FieldDeclarationVisitor({
    required this.context,
  });

  final _Context context;

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (node.isStatic) return;

    log.finer('_FieldDeclarationVisitor: visit($node)');

    for (final decl in node.fields.variables) {
      log.finest('_FieldDeclarationVisitor: check $decl');

      if (decl.isConst) continue;

      context.addClassField(decl.name);
    }
  }
}

class _BuildVisitor extends SimpleAstVisitor<void> {
  _BuildVisitor({
    required this.context,
    required this.onMissingDepsReport,
    required this.onUnnecessaryDepsReport,
  });

  final _Context context;
  final Function(List<Identifier>, AstNode) onMissingDepsReport;
  final Function(List<Identifier>, AstNode) onUnnecessaryDepsReport;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.name != 'build') return;

    log.finer('_BuildVisitor: visit($node)');

    final block = node.findChild<BlockFunctionBody>()?.findChild<Block>();

    if (block == null) return;

    final variableDeclarationVisitor =
        _VariableDeclarationVisitor(context: context);

    block.visitChildren(variableDeclarationVisitor);

    final useEffectVisitor = _UseEffectVisitor(
      context: context,
      onMissingDepsReport: onMissingDepsReport,
      onUnnecessaryDepsReport: onUnnecessaryDepsReport,
    );

    block.visitChildren(useEffectVisitor);
  }
}

class _VariableDeclarationVisitor extends SimpleAstVisitor<void> {
  _VariableDeclarationVisitor({
    required this.context,
  });

  final _Context context;

  @override
  void visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    log.finer('_VariableDeclarationVisitor: visit($node)');

    final decl = node
        .findChild<VariableDeclarationList>()
        ?.findChild<VariableDeclaration>();

    if (decl == null) return;
    if (decl.isConst) return;

    final initializer = decl.initializer;

    if (initializer is MethodInvocation &&
        initializer.methodName.name == 'useState') return;

    if (initializer is MethodInvocation &&
        initializer.methodName.name == 'useRef') return;

    context.addLocalVariable(decl.name);
  }
}

class _UseEffectVisitor extends SimpleAstVisitor<void> {
  _UseEffectVisitor({
    required this.context,
    required this.onMissingDepsReport,
    required this.onUnnecessaryDepsReport,
  });

  final _Context context;
  final Function(List<Identifier>, AstNode) onMissingDepsReport;
  final Function(List<Identifier>, AstNode) onUnnecessaryDepsReport;

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    log.finer('_UseEffectVisitor: visit($node)');

    final inv = node.findChild<MethodInvocation>();

    if (inv == null) return;

    if (inv.methodName.name == 'useEffect') {
      log.finest('_UseEffectVisitor: useEffect found');

      final actualDeps = <Identifier>[];
      final expectedDeps = <Identifier>[];

      final arguments = inv.argumentList.arguments;

      if (arguments.isNotEmpty) {
        if (arguments.length == 1) {
          log.finest('_UseEffectVisitor: useEffect without deps');
        }

        if (arguments.length == 2) {
          log.finest('_UseEffectVisitor: useEffect with deps');

          final deps = arguments[1];

          if (deps is ListLiteral) {
            log.finest('_UseEffectVisitor: useEffect with list deps');

            final visitor = _DepsIdentifierVisitor(
              context: context,
            );

            deps.visitChildren(visitor);

            actualDeps.addAll(visitor.idents);

            log.finest('_UseEffectVisitor: actual deps $actualDeps');
          }
        }

        final visitor = _DepsIdentifierVisitor(
          context: context,
        );

        final body = arguments[0];
        body.visitChildren(visitor);

        expectedDeps.addAll(visitor.idents);

        log.finest('_UseEffectVisitor: expected deps $expectedDeps');

        final missingDeps = <Identifier>[];
        final unnecessaryDeps = <Identifier>[];

        for (final dep in expectedDeps) {
          if (!actualDeps.any(dep.equalsByStaticElement)) {
            missingDeps.add(dep);
          }
        }

        log.finest('_UseEffectVisitor: missing deps $missingDeps');

        for (final dep in actualDeps) {
          if (!expectedDeps.any(dep.equalsByStaticElement)) {
            unnecessaryDeps.add(dep);
          }
        }

        log.finest('_UseEffectVisitor: unnecessary deps $unnecessaryDeps');

        if (missingDeps.isNotEmpty) {
          onMissingDepsReport(
            missingDeps,
            inv,
          );
        }

        if (unnecessaryDeps.isNotEmpty) {
          onUnnecessaryDepsReport(
            unnecessaryDeps,
            inv,
          );
        }
      }
    }
  }
}

class _DepsIdentifierVisitor extends GeneralizingAstVisitor<void> {
  _DepsIdentifierVisitor({
    required this.context,
  });

  final _Context context;

  final List<Identifier> _idents = [];

  @override
  void visitIdentifier(Identifier node) {
    log.finer('_DepsIdentifierVisitor: visit($node)');

    if (node.staticElement == null) return;
    if (!context.isVarialbe(node)) return;

    log.finest('_DepsIdentifierVisitor: $node is variable');

    if (!_idents.any(node.equalsByName)) {
      _idents.add(node);
    } else {
      log.finest('_DepsIdentifierVisitor: $node is already added');
    }
  }

  List<Identifier> get idents => _idents;
}
