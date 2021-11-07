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

        final hooksVisitor = _HooksVisitor(
          context: context,
          onMissingKeyReport: onMissingKeyReport,
          onUnnecessaryKeyReport: onUnnecessaryKeyReport,
        );

        node.visitChildren(hooksVisitor);
      },
    ),
  );
}

/// Key represents complex identifier like 'hoge.foo.bar'
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

  /// iterates over staticElements corresponding to the identifiers
  Iterable<Element> get staticElements =>
      _idents.map((i) => i.staticElement).whereType<Element>();

  bool hasElement(Element other) {
    return staticElements.any(
      (l) => l.id == other.id,
    );
  }

  /// check whether the other Key is subset of this Key
  bool accepts(Key other) {
    if (staticElements.first.id != other.staticElements.first.id) {
      return false;
    }

    if (idents.length < other.idents.length) {
      return false;
    }

    // FIXME: In some cases, the same two identifiers return null or element by context.
    //   To handle this, here compares identifier's name only.
    for (var i = 1; i < other.idents.length; i++) {
      final l = idents[i];
      final r = other.idents[i];

      if (l.name != r.name) return false;
    }

    return true;
  }

  /// shorten the Key
  Key toBaseKey() {
    // if the Key is a state value, keep first 2 identifiers (e.g. state.value.foo => state.value)
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

  /// returns whether the variable is a build-related variable (class fields, local variables, ...)
  bool isBuildVariable(Key variable) {
    log.finer('_Context: isBuildVarialbe($variable)');

    // consider reference like 'state.value' as a build variable ('state' is not)
    if (variable.staticElements.length >= 2) {
      final first = variable.staticElements.first;

      if (_elementContains(_stateVariables, first)) {
        log.finest('_Context: isBuildVarialbe($variable) => state value');
        return true;
      }
    }

    final classFieldGetters =
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

      if (_elementContains(classFieldGetters, element)) {
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

    // ignore values generated by useState, useRef
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

class _HooksVisitor extends SimpleAstVisitor<void> {
  _HooksVisitor({
    required this.context,
    required this.onMissingKeyReport,
    required this.onUnnecessaryKeyReport,
  });

  final _Context context;

  final ExhaustiveKeysReportCallback onMissingKeyReport;
  final ExhaustiveKeysReportCallback onUnnecessaryKeyReport;

  void _visitHookInvocation(MethodInvocation inv) {
    log.finer('_HooksVisitor: _visitHookInvocation($inv)');

    switch (inv.methodName.name) {
      case 'useEffect':
      case 'useMemoized':
      case 'useCallback':
        log.finest('_HooksVisitor: hooks found');

        final actualKeys = <Key>[];
        final expectedKeys = <Key>[];

        final arguments = inv.argumentList.arguments;

        // find identifiers in the hook's keys
        if (arguments.isNotEmpty) {
          // useEffect(() { ... });
          if (arguments.length == 1) {
            log.finest('_HooksVisitor: hooks without keys');
          }

          // useEffect(() { ... }, ...);
          if (arguments.length == 2) {
            log.finest('_HooksVisitor: hooks with keys');

            final keys = arguments[1];

            // useEffect(() { ... }, [...]);
            if (keys is ListLiteral) {
              log.finest('_HooksVisitor: hooks with list keys');

              final visitor = _KeysIdentifierVisitor(
                context: context,
              );

              keys.visitChildren(visitor);

              actualKeys.addAll(visitor.keys);

              log.finest('_HooksVisitor: actual keys $actualKeys');
            }
          }

          // find identifiers in the hook body
          final visitor = _KeysIdentifierVisitor(
            context: context,
            onlyBuildVaribles: true,
          );

          final body = arguments[0];
          body.visitChildren(visitor);

          expectedKeys.addAll(visitor.keys);

          log.finest('_HooksVisitor: expected keys $expectedKeys');

          final missingKeys = <Key>{};
          final unnecessaryKeys = <Key>{};

          for (final key in expectedKeys) {
            if (!actualKeys.any(key.accepts)) {
              missingKeys.add(key.toBaseKey());
            }
          }

          log.finest('_HooksVisitor: missing keys $missingKeys');

          // consider the Keys which is not accepted by every expectedKeys as 'unnecessary'
          for (final key in actualKeys) {
            if (!expectedKeys.any((expected) => expected.accepts(key))) {
              unnecessaryKeys.add(key);
            }
          }

          log.finest('_HooksVisitor: unnecessary keys $unnecessaryKeys');

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

  @override
  void visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    log.finer('_HooksVisitor: visitVariableDeclarationStatement($node)');

    final inv = node
        .findChild<VariableDeclarationList>()
        ?.findChild<VariableDeclaration>()
        ?.findChild<MethodInvocation>();

    if (inv == null) return;

    _visitHookInvocation(inv);
  }

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    log.finer('_HooksVisitor: visitExpressionStatement($node)');

    final inv = node.findChild<MethodInvocation>();

    if (inv == null) return;

    _visitHookInvocation(inv);
  }
}

// find complex identifier like 'hoge.foo.bar' consisting of PropertyAccess, PrefixedIdentifier, SimpleIdentifier
class _KeysIdentifierVisitor extends RecursiveAstVisitor<void> {
  _KeysIdentifierVisitor({
    required this.context,
    this.onlyBuildVaribles = false,
  });

  final _Context context;
  final bool onlyBuildVaribles;

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

    if (onlyBuildVaribles) {
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
