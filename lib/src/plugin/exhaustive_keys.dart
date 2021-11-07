import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:flutter_hooks_lint_plugin/src/plugin/hook_widget_visitor.dart';
import 'package:logging/logging.dart';

final log = Logger('exhaustive_keys');

typedef ExhaustiveKeysReportCallback = void Function(
  String,
  AstNode,
);

void findExhaustiveKeys(
  CompilationUnit unit, {
  required ExhaustiveKeysReportCallback onMissingKeyReport,
  required ExhaustiveKeysReportCallback onUnnecessaryKeyReport,
}) {
  log.finer('findExhaustiveKeys');

  unit.visitChildren(
    HookWidgetVisitor(
      contextBuilder: () => _Context(),
      onClassDeclaration: (_Context context, node) {
        context.addClassFields(node);
      },
      onBuildBlock: (_Context context, node, elem) {
        final variableDeclarationVisitor =
            _LocalVariableVisitor(context: context);

        node.visitChildren(variableDeclarationVisitor);

        final useEffectVisitor = _UseEffectVisitor(
          context: context,
          onMissingKeyReport: onMissingKeyReport,
          onUnnecessaryKeyReport: onUnnecessaryKeyReport,
        );

        node.visitChildren(useEffectVisitor);
      },
    ),
  );
}

class Key {
  Key(List<SimpleIdentifier> idents, bool isStateValue)
      : _idents = idents,
        _isStateValue = isStateValue,
        assert(idents.isNotEmpty);

  factory Key.withContext(_Context context, List<SimpleIdentifier> idents) =>
      Key(
        idents,
        context.hasStateVariable(idents),
      );

  final List<SimpleIdentifier> _idents;
  List<SimpleIdentifier> get idents => _idents;

  final bool _isStateValue;
  bool get isStateValue => _isStateValue;

  Iterable<Element> get staticElements =>
      _idents.map((i) => i.staticElement).whereType<Element>();

  bool hasElement(Element other) {
    return staticElements.any(
      (l) => l.id == other.id,
    );
  }

  bool accepts(Key other) {
    if (staticElements.first.id != other.staticElements.first.id) {
      return false;
    }

    if (idents.length < other.idents.length) {
      return false;
    }

    for (var i = 1; i < other.idents.length; i++) {
      final l = idents[i];
      final r = other.idents[i];

      if (l.name != r.name) return false;
    }

    return true;
  }

  Key toEssentialKey() {
    if (isStateValue) {
      return Key(idents.sublist(0, 2), true);
    }

    return Key([idents.first], false);
  }

  @override
  String toString() {
    return idents.map((i) => i.name).join('.');
  }

  @override
  bool operator ==(Object other) =>
      other is Key &&
      _idents.length == other.idents.length &&
      staticElements.every(other.hasElement);

  @override
  int get hashCode => staticElements.fold(0, (prev, e) => prev ^ e.hashCode);
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

  bool isBuildVariable(Key variable) {
    log.finer('_Context: isBuildVarialbe($variable)');

    if (variable.staticElements.length >= 2) {
      final first = variable.staticElements.first;

      if (_elementContains(_stateVariables, first)) {
        log.finest('_Context: isBuildVarialbe($variable) => state value');
        return true;
      }
    }

    final classFields =
        _classFields.map((e) => e.getter).whereType<Element>().toList();

    for (final element in variable.staticElements) {
      if (_elementContains(_localVariables, element)) {
        log.finest('_Context: isBuildVarialbe($variable) => local variable');
        return true;
      }

      if (_elementContains(_classFields, element)) {
        log.finest('_Context: isBuildVariable($variable) => class field');
        return true;
      }

      if (_elementContains(classFields, element)) {
        log.finest(
            '_Context: isBuildVariable($variable) => class getter field');
        return true;
      }
    }

    log.finest('_Context: isBuildVariable($variable) => not build variable');
    return false;
  }

  bool hasStateVariable(List<Identifier> idents) {
    if (idents.isEmpty) return false;
    final element = idents.first.staticElement;
    return element != null && _elementContains(_stateVariables, element);
  }

  bool _elementContains(List<Element> list, Element target) {
    return list.any((e) => e.id == target.id);
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

    final elem = decl.name.staticElement;

    if (elem is! LocalVariableElement) {
      log.finest(
          '_VariableDeclarationVisitor: visit($node) => variable is not LocalVariableElement');
      return;
    }

    final initializer = decl.initializer;

    if (initializer is MethodInvocation &&
        initializer.methodName.name == 'useState') {
      log.finest(
          '_VariableDeclarationVisitor: visit($node) => variable is useState');

      context.addStateVariable(elem);
      return;
    }

    if (initializer is MethodInvocation &&
        initializer.methodName.name == 'useRef') {
      log.finest(
          '_VariableDeclarationVisitor: visit($node) => variable is useRef');
      return;
    }

    context.addLocalVariable(elem);
  }
}

class _UseEffectVisitor extends SimpleAstVisitor<void> {
  _UseEffectVisitor({
    required this.context,
    required this.onMissingKeyReport,
    required this.onUnnecessaryKeyReport,
  });

  final _Context context;

  final ExhaustiveKeysReportCallback onMissingKeyReport;
  final ExhaustiveKeysReportCallback onUnnecessaryKeyReport;

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    log.finer('_UseEffectVisitor: visit($node)');

    final inv = node.findChild<MethodInvocation>();

    if (inv == null) return;

    if (inv.methodName.name == 'useEffect') {
      log.finest('_UseEffectVisitor: useEffect found');

      final actualKeys = <Key>[];
      final expectedKeys = <Key>[];

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

            actualKeys.addAll(visitor.keys);

            log.finest('_UseEffectVisitor: actual keys $actualKeys');
          }
        }

        final visitor = _KeysIdentifierVisitor(
          context: context,
          awareBuildVaribles: true,
        );

        final body = arguments[0];
        body.visitChildren(visitor);

        expectedKeys.addAll(visitor.keys);

        log.finest('_UseEffectVisitor: expected keys $expectedKeys');

        final missingKeys = <Key>{};
        final unnecessaryKeys = <Key>{};

        for (final key in expectedKeys) {
          if (!actualKeys.any(key.accepts)) {
            missingKeys.add(key.toEssentialKey());
          }
        }

        log.finest('_UseEffectVisitor: missing keys $missingKeys');

        for (final key in actualKeys) {
          if (!expectedKeys.any((expected) => expected.accepts(key))) {
            unnecessaryKeys.add(key);
          }
        }

        log.finest('_UseEffectVisitor: unnecessary keys $unnecessaryKeys');

        for (final key in missingKeys) {
          onMissingKeyReport(
            key.toString(),
            inv,
          );
        }

        for (final key in unnecessaryKeys) {
          onUnnecessaryKeyReport(
            key.toString(),
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
    this.awareBuildVaribles = false,
  });

  final _Context context;
  final bool awareBuildVaribles;

  final List<Key> _keys = [];

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    log.finer('_KeysIdentifierVisitor: visitPrefixedIdentifier($node)');

    final idents = [node.prefix, node.identifier];

    _visitKey(Key.withContext(context, idents));
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    log.finer('_KeysIdentifierVisitor: visitPropertyAccess($node)');

    final visitor = _PropertyAccessVisitor();

    node.visitChildren(visitor);

    final idents = visitor.idents;

    _visitKey(Key.withContext(context, idents));
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    log.finer('_KeysIdentifierVisitor: visitSimpleIdentifier($node)');

    _visitKey(Key.withContext(context, [node]));

    return super.visitSimpleIdentifier(node);
  }

  void _visitKey(Key? key) {
    log.finer('_KeysIdentifierVisitor: _visitKey($key)');

    if (key == null) {
      log.finest(
          '_KeysIdentifierVisitor: _visitKey($key) => keyent is not resolved');
      return;
    }

    if (awareBuildVaribles) {
      final isBuildVariable = context.isBuildVariable(key);

      if (!isBuildVariable) {
        log.finest(
            '_KeysIdentifierVisitor: _visitKey($key) => is build variable');
        return;
      }
    }

    if (!_keys.contains(key)) {
      log.finest('_KeysIdentifierVisitor: _visitKey($key) => add');
      _keys.add(key);
    } else {
      log.finest('_KeysIdentifierVisitor: _visitKey($key) => already added');
    }
  }

  List<Key> get keys => _keys;
}

class _PropertyAccessVisitor extends RecursiveAstVisitor<void> {
  _PropertyAccessVisitor();

  List<SimpleIdentifier> idents = [];

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    idents.insertAll(0, [node.prefix, node.identifier]);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    idents.add(node);

    return super.visitSimpleIdentifier(node);
  }
}
