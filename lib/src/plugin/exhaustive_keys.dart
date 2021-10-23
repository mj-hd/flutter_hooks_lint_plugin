import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:flutter_hooks_lint_plugin/src/plugin/hook_widget_visitor.dart';
import 'package:logging/logging.dart';

final log = Logger('exhaustive_keys');

void findExhaustiveKeys(
  CompilationUnit unit, {
  required void Function(List<Element>, AstNode) onMissingKeysReport,
  required void Function(List<Element>, AstNode) onUnnecessaryKeysReport,
}) {
  log.finer('findExhaustiveKeys');

  final context = _Context();

  unit.visitChildren(
    HookWidgetVisitor(
      context,
      onClassDeclaration: (_Context context, node) {
        context.addClassFields(node);
      },
      onBuildBlock: (_Context context, node, elem) {
        final variableDeclarationVisitor =
            _LocalVariableVisitor(context: context);

        node.visitChildren(variableDeclarationVisitor);

        final useEffectVisitor = _UseEffectVisitor(
          context: context,
          onMissingKeysReport: onMissingKeysReport,
          onUnnecessaryKeysReport: onUnnecessaryKeysReport,
        );

        node.visitChildren(useEffectVisitor);
      },
    ),
  );
}

class _Context {
  final List<FieldElement> _classFields = [];
  final List<VariableElement> _localVariables = [];
  final List<VariableElement> _stateVariables = [];

  void addLocalVariable(VariableElement variable) {
    log.finer('_Context: addLocalVariable($variable)');

    _localVariables.add(variable);
  }

  void addStateVariable(VariableElement variable) {
    log.finer('_Context: addStateVariable($variable)');

    _stateVariables.add(variable);
  }

  void addClassFields(ClassDeclaration klass) {
    log.finer('_Context: addClassFields($klass)');

    if (klass.declaredElement == null) {
      log.finer('_Context: class element is not resolved');
      return;
    }

    _classFields.addAll(
      klass.declaredElement!.fields.where(
        (elem) => !elem.isConst,
      ),
    );
  }

  bool isBuildVarialbe(Element variable) {
    log.finer('_Context: isBuildVarialbe($variable)');

    if (_localVariables.contains(variable)) {
      log.finest('_Context: isBuildVarialbe($variable) => local variable');
      return true;
    }

    if (_classFields.contains(variable)) {
      log.finest('_Context: isBuildVariable($variable) => class field');
      return true;
    }

    if (_classFields.map((e) => e.getter).contains(variable)) {
      log.finest('_Context: isBuildVariable($variable) => class getter field');
      return true;
    }

    log.finest('_Context: isBuildVariable($variable) => not build variable');
    return false;
  }

  bool isStateVariable(Element variable) {
    return _stateVariables.contains(variable);
  }
}

class _LocalVariableVisitor extends SimpleAstVisitor<void> {
  _LocalVariableVisitor({
    required this.context,
  });

  final _Context context;

  @override
  void visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    log.finer('_VariableDeclarationVisitor: visit($node)');

    final decl = node
        .findChild<VariableDeclarationList>()
        ?.findChild<VariableDeclaration>();

    if (decl == null) {
      log.finest(
          '_VariableDeclarationVisitor: visit($node) => variable declaration not found');
      return;
    }
    if (decl.isConst) {
      log.finest(
          '_VariableDeclarationVisitor: visit($node) => variable is const');
      return;
    }

    final initializer = decl.initializer;

    if (initializer is MethodInvocation &&
        initializer.methodName.name == 'useState') {
      log.finest(
          '_VariableDeclarationVisitor: visit($node) => variable is useState');
      return;
    }

    if (initializer is MethodInvocation &&
        initializer.methodName.name == 'useRef') {
      log.finest(
          '_VariableDeclarationVisitor: visit($node) => variable is useRef');
      return;
    }

    final elem = decl.name.staticElement;

    if (elem is! LocalVariableElement) {
      log.finest(
          '_VariableDeclarationVisitor: visit($node) => variable is not LocalVariableElement');
      return;
    }

    context.addLocalVariable(elem);
  }
}

class _UseEffectVisitor extends SimpleAstVisitor<void> {
  _UseEffectVisitor({
    required this.context,
    required this.onMissingKeysReport,
    required this.onUnnecessaryKeysReport,
  });

  final _Context context;
  final void Function(List<Element>, AstNode) onMissingKeysReport;
  final void Function(List<Element>, AstNode) onUnnecessaryKeysReport;

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    log.finer('_UseEffectVisitor: visit($node)');

    final inv = node.findChild<MethodInvocation>();

    if (inv == null) return;

    if (inv.methodName.name == 'useEffect') {
      log.finest('_UseEffectVisitor: useEffect found');

      final actualKeys = <Element>[];
      final expectedKeys = <Element>[];

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
          test: (elem) => context.isBuildVarialbe(elem),
        );

        final body = arguments[0];
        body.visitChildren(visitor);

        expectedKeys.addAll(visitor.idents);

        log.finest('_UseEffectVisitor: expected keys $expectedKeys');

        final missingKeys = <Element>[];
        final unnecessaryKeys = <Element>[];

        for (final key in expectedKeys) {
          if (!actualKeys.contains(key)) {
            missingKeys.add(key);
          }
        }

        log.finest('_UseEffectVisitor: missing keys $missingKeys');

        for (final key in actualKeys) {
          if (!expectedKeys.contains(key)) {
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

class _KeysIdentifierVisitor extends RecursiveAstVisitor<void> {
  _KeysIdentifierVisitor({
    required this.context,
    this.test,
  });

  final _Context context;

  final List<Element> _idents = [];
  final bool Function(Element elem)? test;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    log.finer('_KeysIdentifierVisitor: visitPrefixedIdentifier($node)');

    final prefix = node.prefix.staticElement;
    if (prefix != null && context.isStateVariable(prefix)) {
      _visitElement(node.identifier.staticElement);
    }
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    log.finer('_KeysIdentifierVisitor: visitPropertyAccess($node)');

    final visitor = _PropertyAccessVisitor(node.propertyName);

    node.visitChildren(visitor);

    final idents = visitor.idents;

    if (idents.isNotEmpty) {
      final first = idents.first.staticElement;

      if (first != null && context.isStateVariable(first)) {
        final last = idents.last;
        _visitElement(last.staticElement);
      }
    }
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    log.finer('_KeysIdentifierVisitor: visitIndexExpression($node)');
    final elem = node.staticElement;

    _visitElement(elem);

    return super.visitIndexExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    log.finer('_KeysIdentifierVisitor: visitSimpleIdentifier($node)');
    final elem = node.staticElement;

    _visitElement(elem);

    return super.visitSimpleIdentifier(node);
  }

  void _visitElement(Element? elem) {
    log.finer('_KeysIdentifierVisitor: _visitElement($elem)');

    if (elem == null) {
      log.finest(
          '_KeysIdentifierVisitor: _visitElement($elem) => element is not resolved');
      return;
    }

    if (test != null && !test!(elem)) {
      log.finest(
          '_KeysIdentifierVisitor: _visitElement($elem) => test not passed');
      return;
    }

    if (!_idents.contains(elem)) {
      log.finest('_KeysIdentifierVisitor: _visitElement($elem) => add');
      _idents.add(elem);
    } else {
      log.finest(
          '_KeysIdentifierVisitor: _visitElement($elem) => already added');
    }
  }

  List<Element> get idents => _idents;
}

class _PropertyAccessVisitor extends RecursiveAstVisitor<void> {
  _PropertyAccessVisitor(SimpleIdentifier propertyName)
      : idents = [propertyName];

  List<SimpleIdentifier> idents;

  @override
  void visitPropertyAccess(PropertyAccess node) {
    idents.insert(0, node.propertyName);

    return super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    idents.insertAll(0, [node.prefix, node.identifier]);
  }
}
