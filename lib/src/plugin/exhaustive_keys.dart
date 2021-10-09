import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:logging/logging.dart';

final log = Logger('exhaustive_keys');

void findExhaustiveKeys(
  CompilationUnit unit, {
  required Function(List<Identifier>, AstNode) onMissingKeysReport,
  required Function(List<Identifier>, AstNode) onUnnecessaryKeysReport,
}) {
  log.finer('findExhaustiveKeys');

  final context = _Context();

  unit.visitChildren(
    _HookWidgetVisitor(
      context: context,
      onMissingKeysReport: onMissingKeysReport,
      onUnnecessaryKeysReport: onUnnecessaryKeysReport,
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
    required this.onMissingKeysReport,
    required this.onUnnecessaryKeysReport,
  });

  final _Context context;
  final Function(List<Identifier>, AstNode) onMissingKeysReport;
  final Function(List<Identifier>, AstNode) onUnnecessaryKeysReport;

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
          onMissingKeysReport: onMissingKeysReport,
          onUnnecessaryKeysReport: onUnnecessaryKeysReport,
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
    required this.onMissingKeysReport,
    required this.onUnnecessaryKeysReport,
  });

  final _Context context;
  final Function(List<Identifier>, AstNode) onMissingKeysReport;
  final Function(List<Identifier>, AstNode) onUnnecessaryKeysReport;

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
      onMissingKeysReport: onMissingKeysReport,
      onUnnecessaryKeysReport: onUnnecessaryKeysReport,
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
    required this.onMissingKeysReport,
    required this.onUnnecessaryKeysReport,
  });

  final _Context context;
  final Function(List<Identifier>, AstNode) onMissingKeysReport;
  final Function(List<Identifier>, AstNode) onUnnecessaryKeysReport;

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    log.finer('_UseEffectVisitor: visit($node)');

    final inv = node.findChild<MethodInvocation>();

    if (inv == null) return;

    if (inv.methodName.name == 'useEffect') {
      log.finest('_UseEffectVisitor: useEffect found');

      final actualKeys = <Identifier>[];
      final expectedKeys = <Identifier>[];

      final arguments = inv.argumentList.arguments;

      if (arguments.isNotEmpty) {
        if (arguments.length == 1) {
          log.finest('_UseEffectVisitor: useEffect without keys');
        }

        if (arguments.length == 2) {
          log.finest('_UseEffectVisitor: useEffect with keys');

          final keys = arguments[1];

          if (keys is ListLiteral) {
            log.finest('_UseEffectVisitor: useEffect with list keys');

            final visitor = _KeysIdentifierVisitor(
              context: context,
            );

            keys.visitChildren(visitor);

            actualKeys.addAll(visitor.idents);

            log.finest('_UseEffectVisitor: actual keys $actualKeys');
          }
        }

        final visitor = _KeysIdentifierVisitor(
          context: context,
        );

        final body = arguments[0];
        body.visitChildren(visitor);

        expectedKeys.addAll(visitor.idents);

        log.finest('_UseEffectVisitor: expected keys $expectedKeys');

        final missingKeys = <Identifier>[];
        final unnecessaryKeys = <Identifier>[];

        for (final key in expectedKeys) {
          if (!actualKeys.any(key.equalsByStaticElement)) {
            missingKeys.add(key);
          }
        }

        log.finest('_UseEffectVisitor: missing keys $missingKeys');

        for (final key in actualKeys) {
          if (!expectedKeys.any(key.equalsByStaticElement)) {
            unnecessaryKeys.add(key);
          }
        }

        log.finest('_UseEffectVisitor: unnecessary keys $unnecessaryKeys');

        if (missingKeys.isNotEmpty) {
          onMissingKeysReport(
            missingKeys,
            inv,
          );
        }

        if (unnecessaryKeys.isNotEmpty) {
          onUnnecessaryKeysReport(
            unnecessaryKeys,
            inv,
          );
        }
      }
    }
  }
}

class _KeysIdentifierVisitor extends GeneralizingAstVisitor<void> {
  _KeysIdentifierVisitor({
    required this.context,
  });

  final _Context context;

  final List<Identifier> _idents = [];

  @override
  void visitIdentifier(Identifier node) {
    log.finer('_KeysIdentifierVisitor: visit($node)');

    if (node.staticElement == null) return;
    if (!context.isVarialbe(node)) return;

    log.finest('_KeysIdentifierVisitor: $node is variable');

    if (!_idents.any(node.equalsByName)) {
      _idents.add(node);
    } else {
      log.finest('_KeysIdentifierVisitor: $node is already added');
    }
  }

  List<Identifier> get idents => _idents;
}
